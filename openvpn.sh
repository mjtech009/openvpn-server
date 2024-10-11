#!/bin/bash -ex
# Function to handle domain input and validation
get_domain() {
  if [ -z "$1" ]; then  # Check if a domain argument is provided
    read -p "Enter your domain name (e.g., domain.com): " DOMAIN
    while ! [[ "$DOMAIN" =~ ^[a-zA-Z0-9-.]+$ ]]; do
      read -p "Invalid domain. Please enter a valid domain name: " DOMAIN
    done
  else
    DOMAIN="$1"  # Use the provided argument
  fi
}

# Get the domain name (either from argument or user input)
get_domain "$@"

# Install dependencies (if not already installed)
if ! command -v certbot &> /dev/null; then
  echo "Installing openvpn....."
  sudo bash <(curl -fsS https://packages.openvpn.net/as/install.sh) --yes
  echo "Installing certbot..."
  sudo apt-get update -y
  sudo apt-get install -y software-properties-common
  sudo add-apt-repository -y ppa:certbot/certbot   
  sudo apt-get update
  sudo apt-get install -y certbot   

fi

# Stop OpenVPN service (if running)
sudo service openvpnas stop

# Delete existing certificates
/usr/local/openvpn_as/scripts/confdba -mk cs.ca_bundle
/usr/local/openvpn_as/scripts/confdba -mk cs.priv_key
/usr/local/openvpn_as/scripts/confdba -mk cs.cert

# Generate certificates through Let's Encrypt
sudo certbot certonly \
  --standalone \
  --non-interactive \
  --agree-tos \
  --register-unsafely-without-email \
  --domains '$DOMAIN' \
  --pre-hook 'sudo service openvpnas stop' \
  --post-hook 'sudo service openvpnas start'

# symlink the generated certificates to the OpenVPN certificate location
sudo ln -s -f /etc/letsencrypt/live/$DOMAIN/cert.pem /usr/local/openvpn_as/etc/web-ssl/server.crt
sudo ln -s -f /etc/letsencrypt/live/$DOMAIN/privkey.pem /usr/local/openvpn_as/etc/web-ssl/server.key
sudo ln -s -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem /usr/local/openvpn_as/etc/web-ssl/ca.crt  


echo "Certificates generated successfully for domain: $DOMAIN"
