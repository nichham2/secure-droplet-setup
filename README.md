# secure-droplet-setup
This is a secure and modular Linux shell script for setting up a new cloud droplet (like on DigitalOcean, Linode, etc.) with strong default security and flexibility. 

curl -fsSL https://raw.githubusercontent.com/<your-username>/secure-droplet-setup/main/secure-setup.sh | sudo bash -s -- \
  SSH_KEY_URL="https://yourdomain.com/yourkey.pub" \
  SSH_PORT="2200" \
  NEW_USER="devadmin"

