cd ..
cd ./request

echo "Generating docker image"
docker build -t request .
docker tag request therealflash/request
echo "Uploading docker image"
docker push therealflash/request
echo "Docker task completed successfully!"