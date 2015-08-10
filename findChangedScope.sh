#!/bin/bash

projectDir=$1
if [ ! -z "$projectDir" -a "$projectDir" != " " ]; then
    if [ "${projectDir: -1}" != '/' ]; then
        projectDir="$projectDir/"
    fi
else
    exit 1
fi

poms=$(find $projectDir -name pom.xml)

defaultScope="compile"

for i in $poms; do
    workDir=$(echo $i | sed 's\pom.xml\\')
	cd $workDir
    mvn help:effective-pom -Doutput=effective.pom.xml > /dev/null
    if [[ $? != 0 ]]; then
        echo "Maven effective pom creation failed in: "$workDir"pom.xml"
        continue
    fi
    dependenciesEffectivePom=$(echo "cat //*[local-name()='project']/*[local-name()='dependencies']/*[local-name()='dependency']/*[local-name()='artifactId']/text()" | xmllint --shell effective.pom.xml | sed '/^\/ >/d' | sed 's/<[^>]*.//g' | sed -n 'p;n')
    dependenciesPom=$(echo "cat //*[local-name()='project']/*[local-name()='dependencies']/*[local-name()='dependency']/*[local-name()='artifactId']/text()" | xmllint --shell pom.xml | sed '/^\/ >/d' | sed 's/<[^>]*.//g' | sed -n 'p;n')
    if [ -z "$dependenciesPom" ]; then
        rm effective.pom.xml
        continue
    elif [ "$dependenciesEffectivePom" != "$dependenciesPom" ]; then
        echo "Different dependency count in: "$workDir"pom.xml"
    else
        OldIFS=$IFS
        IFS=$'\n'
        differentScopes=""
        for dep in $dependenciesEffectivePom; do
            defaultScopeUsed=false
            scopeEffective=$(echo "cat //*[local-name()='project']/*[local-name()='dependencies']/*[local-name()='dependency' and *[local-name()='artifactId' and text()='$dep']]/*[local-name()='scope']/text()" | xmllint --shell effective.pom.xml | sed '/^\/ >/d' | sed 's/<[^>]*.//g' | sed -n 'p;n')
            scope=$(echo "cat //*[local-name()='project']/*[local-name()='dependencies']/*[local-name()='dependency' and *[local-name()='artifactId' and text()='$dep']]/*[local-name()='scope']/text()" | xmllint --shell pom.xml | sed '/^\/ >/d' | sed 's/<[^>]*.//g' | sed -n 'p;n')
            if [ -z "$scope" ]; then
                scope=$defaultScope
                defaultScopeUsed=true
            fi
            if [ "$scope" != "$scopeEffective" ]; then
                if [ defaultScope ]; then
                    xmlstarlet ed -L -s "//*[local-name()='project']/*[local-name()='dependencies']/*[local-name()='dependency' and *[local-name()='artifactId' and text()='$dep']]" --type elem -n scope -v "$scopeEffective" pom.xml
                    xmlstarlet fo -s 4 pom.xml > pomEdited.xml
                    mv pomEdited.xml pom.xml
                else
                    xmlstarlet ed -L -u "//*[local-name()='project']/*[local-name()='dependencies']/*[local-name()='dependency' and *[local-name()='artifactId' and text()='$dep']]/*[local-name()='scope']" -v "$scopeEffective" pom.xml
                    xmlstarlet fo -s 4 pom.xml > pomEdited.xml
                    mv pomEdited.xml pom.xml
                fi
                differentScopes=$differentScopes$'\n'$dep$'\n'"\"$scope\" != \"$scopeEffective\""
            fi
        done
        IFS=$OlfIFS
        if [ ! -z "$differentScopes" ]; then
            echo "*********************************************************************"
            echo $workDir"pom.xml"
            echo "Updated different scopes:"
            echo $differentScopes
            echo "*********************************************************************"
        fi
    fi
    rm effective.pom.xml
done
