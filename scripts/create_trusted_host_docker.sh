cd ..
cd ./gatekeeper

echo "Generating docker image"
docker build -t trustedHost .
docker tag trustedHost therealflash/trustedHost
echo "Uploading docker image"
docker push therealflash/trustedHost
echo "Docker task completed successfully!"