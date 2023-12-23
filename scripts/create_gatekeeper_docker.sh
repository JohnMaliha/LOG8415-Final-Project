cd ..
cd ./gatekeeper

echo "Generating docker image"
docker build -t gatekeeper .
docker tag gatekeeper therealflash/gatekeeper
echo "Uploading docker image"
docker push therealflash/gatekeeper
echo "Docker task completed successfully!"