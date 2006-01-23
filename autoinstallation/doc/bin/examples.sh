mode=$1
for i in `ls examples/*.xml`; do 
	ent=`basename $i .xml`
	if [ "$mode" == 'min' ]; then
		echo "<!ENTITY  $ent   \"\">"
	else
		echo "<!ENTITY  $ent  SYSTEM \"examples/$ent.xml\">"
	fi
		
done