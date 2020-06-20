#!/bin/bash
USERNAME=1cportal_user
PASSWORD=1cportal_password
DIR="/home/myscript"
configdir="/mnt/tmpls/8.3"
b24url=https://corpportal.bitrix24.ua/rest
b24API=34/41rswye81bpzpqc1
SRC=$(curl -c /tmp/cookies.txt -s -L https://releases.1c.eu)
RSS_URL=https://news.webits.1c.ru/news/updates_ru_eu/rss

rm $DIR/rssfile
rm $DIR/rss
rm $DIR/myproducts

ACTION=$(echo "$SRC" | grep -oP '(?<=form method="post" id="loginForm" action=")[^"]+(?=")')
EXECUTION=$(echo "$SRC" | grep -oP '(?<=input type="hidden" name="execution" value=")[^"]+(?=")')

curl -s -L \
    -o /dev/null \
    -b /tmp/cookies.txt \
    -c /tmp/cookies.txt \
    --data-urlencode "inviteCode=" \
    --data-urlencode "execution=$EXECUTION" \
    --data-urlencode "_eventId=submit" \
    --data-urlencode "username=$USERNAME" \
    --data-urlencode "password=$PASSWORD" \
    https://login.1c.eu"$ACTION"

if ! grep -q "TGC" /tmp/cookies.txt ;then
    echo "Auth failed"
    exit 1
fi


cd $DIR

#формируем список решений, который нас интересует
echo Продукт=Бухгалтерия для Украины > $DIR/myproducts
echo Продукт=Управление производственным предприятием для Украины >> $DIR/myproducts
echo Продукт=Управление торговым предприятием для Украины >> $DIR/myproducts
echo Продукт=Зарплата и Управление Персоналом для Украины >> $DIR/myproducts
echo Продукт=Общепит для Украины >> $DIR/myproducts
echo Продукт=Управление небольшой фирмой для Украины >> $DIR/myproducts
echo Продукт=Управление торговлей для Украины >> $DIR/myproducts
echo Продукт=Бухгалтерія будівельної організації >> $DIR/myproducts
echo Продукт=Бухгалтерия элеватора, мельницы и комбикормового завода для Украины >> $DIR/myproducts
echo Продукт=Бухгалтерия сельскохозяйственного предприятия для Украины >> $DIR/myproducts
echo Продукт=1С:Бухгалтерия сельскохозяйственного предприятия для Украины >> $DIR/myproducts
echo Продукт=1С:Бухгалтерия элеватора, мельницы и комбикормового завода для Украины >> $DIR/myproducts
#echo Продукт=Громадське харчування для України >> $DIR/myproducts
#echo >> $DIR/myproducts


wget ${RSS_URL} -o $DIR/rssfile
for (( i=40; i > 0; i-- ))
do
guid=$(cat $DIR/rss | xmlstarlet sel -t -v "/rss/channel/item["$i"]/guid")
title=$(cat $DIR/rss | xmlstarlet sel -t -v "/rss/channel/item["$i"]/title" | sed 's/&quot;//' | sed 's/"//g')
body=$(cat $DIR/rss | xmlstarlet sel -t -v "/rss/channel/item["$i"]/description" | sed 's/&amr/&/')
vid=$(cat $DIR/rss | xmlstarlet sel -t -v "/rss/channel/item["$i"]/category[2]")
product=$(cat $DIR/rss | xmlstarlet sel -t -v "/rss/channel/item["$i"]/category[1]")
pubDate=$(cat $DIR/rss | xmlstarlet sel -t -v "/rss/channel/item["$i"]/pubDate")
grep -q $guid "$DIR/rsslog" || (

echo "номер новости = " $i
echo Title is $title
echo Produkt = $product

        if [[ $product =~ $(echo ^\($(paste -sd'|' $DIR/myproducts)\)$) ]]
                then
                if [[ $vid = "Вид новости обновлений=Публикация новой версии" ]]
                        then
                        echo "i = " $i
                        echo "Бегом! Качать! " $title
                        echo "Body = " $body
                        URL=$(echo $body | cut -f2 -d'"' | sed 's/\&amp;/\&/')
                        echo "URL is" $URL #(echo $body | cut -f2 -d'"' | sed 's/\&amp;/\&/')
                        ver=$(echo $body | sed 's/.*ver=//' | cut -f1 -d'"')
                        echo "ver = " $ver
                        nick=$(echo $body | cut -f2 -d'"' | sed 's/\&amp;/\&/' | cut -f2 -d'=' | sed 's/\&ver//g')
                        echo "NIK = " $nick
                        nicksmal=$(echo $nick | sed 's/[^a-Z]//g')
                        echo "SmalNick = " $nicksmal

                        #создаём папку, куда будем складировать обновления
                        mkdir -p $configdir/$nicksmal/$ver

                        #скачиваем самораспаковывающийся архив обновления конфигурации
                        relizdistributiv=$(curl -s -G \
                            -b /tmp/cookies.txt \
                            --data-urlencode "nick=$nick" \
                            --data-urlencode "ver=$ver" \
                            --data-urlencode "path=$nicksmal\\$(echo $ver | tr '.' '_')\\$(echo $nicksmal)_$(echo $ver | tr '.' '_')_updsetup.exe" \
                            https://releases.1c.eu/version_file  | grep -oP '(?<=a href=")[^"]+(?=">Скачать дистрибутив<)')

                        curl --fail -b /tmp/cookies.txt -o $configdir/$nicksmal/$ver/$(echo $nicksmal)_$(echo $ver | tr '.' '_')_updsetup.exe -L "$relizdistributiv"


                        # скачиваем описание новости обновления
                        curl -s -G \
                                -b /tmp/cookies.txt \
                                --data-urlencode "nick=$nick" \
                                --data-urlencode "ver=$ver" \
                                --data-urlencode "path=$nicksmal\\$(echo $ver | tr '.' '_')\\news.htm" \
                                -o $configdir/$nicksmal/$ver/news.htm -L https://releases.1c.eu/version_file

                        # выставляем права на скачанные файлы
                        chmod -R 777 $configdir/$nicksmal/$ver

                        #создаём задачу консультантам про выход релиза
                        # API location
                        user=$(echo $b24API | cut -f1 -d"/")
                        lynx --dump $configdir/$nicksmal/$ver/news.htm > /tmp/news.txt
                        b24bodytext=$(cat /tmp/news.txt | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/<BR>/g' | tr '\n' ' ' | tr '"' '*')

                        curlDataZadacha='[{ "TITLE": "'$title'", "DESCRIPTION": "'$b24bodytext'", "RESPONSIBLE_ID": "94", "ACCOMPLICES": ["120", "166", "9", "25"], "AUDITORS": ["118", "1830", "114", "476"], "CREATED_BY": "114"}]'
                        curl -H 'Content-Type: application/json' -d "$curlDataZadacha" $b24url/$b24API/task.item.add

                        #создаём задачу на публикацию новости на сайте
                        curlDataZadachaVadim='[{ "TITLE": "'$title'", "DESCRIPTION": "'$b24bodytext'", "PARENT_ID": "11758", "GROUP_ID": "70", "RESPONSIBLE_ID": "2370", "AUDITORS": ["114", "1830", "7"], "CREATED_BY": "114"}]'
                        curl -H 'Content-Type: application/json' -d "$curlDataZadachaVadim" $b24url/$b24API/task.item.add

                fi

                if [[ $vid = "Вид новости обновлений=Публикация плана версии" ]]
                        then
                        echo "i = " $i
                        echo "Скооро вйдет " $title
                        echo "Body = " $body
                        echo .

                        fi
                fi
        echo $guid >> $DIR/rsslog
        echo $title >> $DIR/rsslog
        echo $pubDate >> $DIR/rsslog
        echo . >> $DIR/rsslog

        )
done



#rm $DIR/rssfile
#rm $DIR/rss
#rm $DIR/myproducts
