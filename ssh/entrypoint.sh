mkdir -p hadoop-docker/ssh
cd hadoop-docker/ssh
ssh-keygen -t rsa -P "" -f ./id_rsa
# Now copy the public key content into authorized_keys
cat id_rsa.pub > authorized_keys
chmod 600 id_rsa authorized_keys # Set permissions
cd ../.. # Go back to the root project directory