#
# Redirect all http to https
#
server {
    server_name               sample.com;
    listen                    80;
    return                    301 https://sample.com$request_uri;
}

server {
    server_name     sample.com;
    listen          443 ssl;

    ssl_certificate           /home/ubuntu/SSL/STAR_sample.com.cer;
    ssl_certificate_key       /home/ubuntu/SSL/STAR_sample.com.key;
    ssl_dhparam               /home/ubuntu/SSL/dhparam.pem;
    ssl_protocols             TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_ciphers               "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
    ssl_ecdh_curve            secp384r1; # Requires nginx >= 1.1.0
    ssl_session_cache         shared:SSL:10m;
    ssl_session_tickets       off; # Requires nginx >= 1.5.9
    ssl_stapling              on; # Requires nginx >= 1.3.7
    ssl_stapling_verify       on; # Requires nginx => 1.3.7
    resolver                  8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout          5s;
  # add_header                Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
    add_header                X-Frame-Options DENY;
    add_header                X-Content-Type-Options nosniff;

    root            /var/www/html/sample.com;

    index index.html index.htm index.php;

    access_log /var/log/nginx/sample.com.access.log;
    access_log /var/log/nginx/sample.com.apachestyle.access.log apachestandard;
    error_log  /var/log/nginx/sample.com.error.log;

    location = /xmlrpc.php { deny all; access_log off; error_log off; }
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt { access_log off; log_not_found off; }
    location = /apple-touch-icon.png { access_log off; log_not_found off; }
    location = /apple-touch-icon-precomposed.png { access_log off; log_not_found off; }
    location ~ /\. { deny  all; access_log off; log_not_found off; }

    location / {
        try_files $uri $uri/ /index.php?q=$uri&$args;
    }
    location ~ \.php$ {
        proxy_intercept_errors on;
        error_page 500 501 502 503 = @fallback;
        fastcgi_buffers 8 256k;
        fastcgi_buffer_size 128k;
        fastcgi_intercept_errors on;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass php;
    }
    location @fallback {
        fastcgi_buffers 8 256k;
        fastcgi_buffer_size 128k;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass php;
    }
    location ~* .(css|js|png|jpg|jpeg|gif|ico)$ { expires 1d; }
}
