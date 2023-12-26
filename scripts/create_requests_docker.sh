cd ..
cd ./request

echo "Generating docker image"
docker build -t request .
echo "Docker task completed successfully!"