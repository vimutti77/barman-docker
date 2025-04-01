read -p "Enter barman version: " BARMAN_VERSION

docker build --build-arg="BARMAN_VERSION=$BARMAN_VERSION" --tag vimutti/barman:$BARMAN_VERSION .
docker push vimutti/barman:$BARMAN_VERSION
