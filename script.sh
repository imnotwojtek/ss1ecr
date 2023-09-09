#!/bin/bash

# Aktualizacja i instalacja wymaganych pakietów
sudo apt update && sudo apt upgrade -y && sudo apt install -y nginx software-properties-common mysql-server phpmyadmin certbot python3-certbot-nginx

# Dodanie repozytorium PHP i instalacja PHP 8.2.10
sudo add-apt-repository ppa:ondrej/php -y && sudo apt update && sudo apt install -y php8.2 php8.2-fpm php8.2-mysql php8.2-mbstring php8.2-xml php8.2-zip

# Generowanie haseł i loginów
generate_password() { openssl rand -base64 64 | tr -dc 'a-zA-Z0-9!@#$%^&*()-+=' | fold -w $(shuf -i $1-$2 -n 1) | head -n 1; }
MYSQL_ROOT_PASSWORD=$(generate_password 12 64)
MYSQL_USER="cyber$(generate_password 10 16)"
MYSQL_USER_PASSWORD=$(generate_password 12 64)
PHPMYADMIN_PASSWORD=$(generate_password 12 64)

# Zapisywanie haseł i loginów
cat > /root/db_credentials.txt <<EOL
MySQL root password: $MYSQL_ROOT_PASSWORD
MySQL username: $MYSQL_USER
MySQL user password: $MYSQL_USER_PASSWORD
phpMyAdmin password: $PHPMYADMIN_PASSWORD
EOL

# Konfiguracja MySQL
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"
echo "CREATE USER '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_USER_PASSWORD'; GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'localhost'; FLUSH PRIVILEGES;" | sudo mysql

# Konfiguracja nginx
cat > /etc/nginx/sites-available/cyberwojtek.com <<EOL
server {
    listen 80;
    server_name cyberwojtek.com www.cyberwojtek.com;
    root /var/www/html;
    index index.php;
    location / { try_files $uri $uri/ =404; }
    location ~ \.php$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:/var/run/php/php8.2-fpm.sock; }
    location ~ /\.ht { deny all; }
    location /phpmyadmin { auth_basic "Admin Login"; auth_basic_user_file /etc/nginx/pma_pass; }
}
EOL
sudo ln -sf /etc/nginx/sites-available/cyberwojtek.com /etc/nginx/sites-enabled/ && sudo nginx -s reload

# Ustawienie hasła dla phpMyAdmin
echo -n "admin:$PHPMYADMIN_PASSWORD" | sudo tee /etc/nginx/pma_pass

# Instalacja certyfikatu SSL
sudo certbot --nginx -d cyberwojtek.com -d www.cyberwojtek.com

# Tworzenie 2GB swapu
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile && echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab

echo "Instalacja zakończona pomyślnie!"
