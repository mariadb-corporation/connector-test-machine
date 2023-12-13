#!/bin/bash -ex

echo "**************************************************************************"
echo "* searching for last complete build"
echo "**************************************************************************"

wget -q -o /dev/null index.html https://buildbot.mariadb.net/archive/pack/11.3/
grep -o ">build-[0-9]*" index.html | grep -o "[0-9]*" | tac | while read -r line ; do

  curl -s --head https://buildbot.mariadb.net/archive/pack/11.3/build-$line/kvm-deb-jammy-amd64/md5sums.txt | head -n 1 | grep "HTTP/1.[01] [23].." > /dev/null
  if [ $? = "0" ]; then
    echo "**************************************************************************"
    echo "* Processing $line"
    echo "**************************************************************************"
    wget -q -o /dev/null -O $line.html  https://buildbot.mariadb.net/archive/pack/11.3/build-$line/kvm-deb-jammy-amd64/debs/binary/
    grep -o ">[^\"]*\.deb" $line.html | grep -o "[^>]*\.deb" | while read -r file ; do
        if  [[ "$file" =~ ^mariadb-plugin.* ]] ;
        then
          echo "skipped file: $file"
        else
          echo "download file: https://buildbot.mariadb.net/archive/pack/11.3/build-$line/kvm-deb-jammy-amd64/debs/binary/$file"
          wget -q -o /dev/null -O $PROJ_PATH/travis/build/$file https://buildbot.mariadb.net/archive/pack/11.3/build-$line/kvm-deb-jammy-amd64/debs/binary/$file
        fi
    done
    echo "DL complete"
    exit
  else
    echo "skip build $line"
  fi
done



