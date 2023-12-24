cd ..
cd ./gatekeeper

echo "Generating docker image"
docker build -t trustedhost .
docker tag trustedhost therealflash/trustedhost
echo "Uploading docker image"
docker push therealflash/trustedhost
echo "Docker task completed successfully!"