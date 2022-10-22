source ./.env

sed -i "s|alias 1| alias ${data}/protected_media/;|g" nginx_proxy
sed -i "s|alias 2| alias ${data}/;|g" nginx_proxy
sed -i "s|alias 3| alias ${scanDirectory}/;|g" nginx_proxy
sed -i "s|alias 4| alias ${data}/nextcloud_media/;|g" nginx_proxy
