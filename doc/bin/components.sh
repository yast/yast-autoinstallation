mode=$1
for i in `ls components/*.xml`; do 
	ent=`basename $i .xml`
	if [ "$mode" == 'min' ]; then
		echo "<!ENTITY  $ent   \"\">"
	else
		echo "<!ENTITY  $ent  SYSTEM \"components/$ent.xml\">"
	fi
		
done
if [ "$mode" == 'min' ]; then
	echo "<!ENTITY  Elements \"\">"
else
	echo "<!ENTITY  Elements SYSTEM \"elements.xml\">"
	echo "<!ENTITY % elements SYSTEM \"elements.ent\">"
	echo "%elements;"
fi
