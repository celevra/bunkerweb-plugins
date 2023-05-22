#!/bin/bash

. .tests/utils.sh

echo "ℹ️ Starting VirusTotal tests ..."

# Create working directory
if [ -d /tmp/bunkerweb-plugins ] ; then
	do_and_check_cmd sudo rm -rf /tmp/bunkerweb-plugins
fi
do_and_check_cmd mkdir -p /tmp/bunkerweb-plugins/virustotal/bw-data/plugins
do_and_check_cmd cp -r ./virustotal /tmp/bunkerweb-plugins/virustotal/bw-data/plugins
do_and_check_cmd sudo chown -R 101:101 /tmp/bunkerweb-plugins/virustotal/bw-data

# Copy compose
do_and_check_cmd cp .tests/virustotal/docker-compose.yml /tmp/bunkerweb-plugins/virustotal

# Edit compose
do_and_check_cmd sed -i "s@bunkerity/bunkerweb:.*\$@bunkerweb:tests@g" /tmp/bunkerweb-plugins/virustotal/docker-compose.yml
do_and_check_cmd sed -i "s@bunkerity/bunkerweb-scheduler:.*\$@bunkerweb-scheduler:tests@g" /tmp/bunkerweb-plugins/virustotal/docker-compose.yml
do_and_check_cmd sed -i "s@%VTKEY%@${VIRUSTOTAL_API_KEY}@g" /tmp/bunkerweb-plugins/virustotal/docker-compose.yml

# Download EICAR file
do_and_check_cmd wget -O /tmp/bunkerweb-plugins/virustotal/eicar.com https://secure.eicar.org/eicar.com

# Do the tests
cd /tmp/bunkerweb-plugins/virustotal
do_and_check_cmd docker-compose up -d

# Check that API is working
echo "ℹ️ Testing API ..."
success="ko"
retry=0
while [ $retry -lt 60 ] ; do
	ret="$(curl -s -X POST -H "Host: www.example.com" -F "file=@/tmp/bunkerweb-plugins/virustotal/eicar.com" http://localhost:8000/check)"
	check="$(echo "$ret" | grep "\"success\":true")"
	if [ $? -eq 0 ] && [ "$check" != "" ] ; then
		check="$(echo "$ret" | grep "\"detected\":true")"
		if [ "$check" != "" ] ; then
			success="ok"
			break
		fi
	fi
	retry=$(($retry + 1))
	sleep 1
done
if [ $retry -eq 120 ] ; then
	echo "❌ Error timeout after 120s"
	docker-compose logs
	docker-compose down -v
	exit 1
fi
if [ "$success" == "ko" ] ; then
	echo "❌ Error EICAR not detected"
	docker-compose logs
	docker-compose down -v
	exit 1
fi
echo "ℹ️ API is working ..."

# Now check if BunkerWeb is giving a 403
echo "ℹ️ Testing BW ..."
success="ko"
retry=0
while [ $retry -lt 120 ] ; do
	ret="$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "Host: www.example.com" -F "file=@/tmp/bunkerweb-plugins/virustotal/eicar.com" http://localhost)"
	if [ $? -eq 0 ] && [ $ret -eq 403 ] ; then
		success="ok"
		break
	fi
	retry=$(($retry + 1))
	sleep 1
done

# We're done
if [ $retry -eq 120 ] ; then
	echo "❌ Error timeout after 120s"
	docker-compose logs
	docker-compose down -v
	exit 1
fi
if [ "$success" == "ko" ] ; then
	echo "❌ Error did not receive 403 code"
	docker-compose logs
	docker-compose down -v
	exit 1
fi
docker-compose down -v

echo "ℹ️ VirusTotal tests done"