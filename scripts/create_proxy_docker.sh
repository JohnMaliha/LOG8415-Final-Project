cd ..
cd ./proxy

echo "Generating docker image"
docker build -t proxy .
docker tag proxy therealflash/proxy
echo "Uploading docker image"
docker push therealflash/proxy
echo "Docker task completed successfully!"