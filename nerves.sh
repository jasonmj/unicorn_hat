#!/run/current-system/sw/bin/sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $DIR
docker-compose up -d

case $1 in
    "burn")
        docker-compose exec -T nerves mix deps.get
        docker-compose exec -T nerves mix firmware.burn
        ;;

    "hotswap")
        docker-compose exec -T nerves mix upload.hotswap
        ;;

    "update")
        docker-compose exec -T nerves mix deps.get
        docker-compose exec -T nerves mix firmware
        docker-compose exec -T nerves mix upload 192.168.0.12
        ;;
esac

exit 0
