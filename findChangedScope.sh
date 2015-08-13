#!/bin/bash
#
# Checks wheter the artifact scopes are the same in the regular pom and in the effective pom (they are not changed by the dependency management)
# If they differs scope from the effective pom is added/updated to the artifact in the regular pom
# 
# Lukas Kubik lkubik@redhat.com
#

if [ $# -ne 1 ]; then
  echo "One argument is expected, usage: $0 top-directory-of-a-maven-project"
  exit 1
fi

projectDir=$1

#check for / suffix in project path and optionally add it
if [ ! -z "$projectDir" -a "$projectDir" != " " ]; then
    if [ "${projectDir: -1}" != '/' ]; then
        projectDir="$projectDir/"
    fi
else
    exit 1
fi

poms=$(find $projectDir -name pom.xml)

#default maven scope if no scope is declared
defaultScope="compile"

for i in $poms; do
    #change directory to pom directory and create an effective pom
    workDir=$(echo $i | sed 's\pom.xml\\')
	cd $workDir
    mvn help:effective-pom -Doutput=effective.pom.xml > /dev/null
    if [[ $? != 0 ]]; then
        echo "Maven effective pom creation failed in: "$workDir"pom.xml"
        continue
    fi

    #parse dependencies from pom and effective pom
    dependenciesEffectivePom=$(echo "cat //*[local-name()='project']/*[local-name()='dependencies']/*[local-name()='dependency']/*[local-name()='artifactId']/text()" | xmllint --shell effective.pom.xml | sed '/^\/ >/d' | sed 's/<[^>]*.//g' | sed -n 'p;n')
    dependenciesPom=$(echo "cat //*[local-name()='project']/*[local-name()='dependencies']/*[local-name()='dependency']/*[local-name()='artifactId']/text()" | xmllint --shell pom.xml | sed '/^\/ >/d' | sed 's/<[^>]*.//g' | sed -n 'p;n')
    #check if there is any dependencies in the regular pom
    if [ -z "$dependenciesPom" ]; then
        rm effective.pom.xml
        continue
    #check whetere the dependencies are same in the effective pom and the regular pom
    elif [ "$dependenciesEffectivePom" != "$dependenciesPom" ]; then
        echo "Different dependency count in: "$workDir"pom.xml"
    else
        OldIFS=$IFS
        IFS=$'\n'
        differentScopes=""
        #parse scopes for all parsed dependencies and optinally update them
        for dep in $dependenciesEffectivePom; do
            defaultScopeUsed=false
            #parsing scopes
            scopeEffective=$(echo "cat //*[local-name()='project']/*[local-name()='dependencies']/*[local-name()='dependency' and *[local-name()='artifactId' and text()='$dep']]/*[local-name()='scope']/text()" | xmllint --shell effective.pom.xml | sed '/^\/ >/d' | sed 's/<[^>]*.//g' | sed -n 'p;n')
            scope=$(echo "cat //*[local-name()='project']/*[local-name()='dependencies']/*[local-name()='dependency' and *[local-name()='artifactId' and text()='$dep']]/*[local-name()='scope']/text()" | xmllint --shell pom.xml | sed '/^\/ >/d' | sed 's/<[^>]*.//g' | sed -n 'p;n')
            #checks wheter the scope in the regular pom is defined and optionally use default scope (compile)
            if [ -z "$scope" ]; then
                scope=$defaultScope
                defaultScopeUsed=true
            fi
            #checks whtere the scopes differ and if yes the update the regular pom
            if [ "$scope" != "$scopeEffective" ]; then
                if [ defaultScope ]; then
                    #add
                    xmlstarlet ed -L -P -s "//*[local-name()='project']/*[local-name()='dependencies']/*[local-name()='dependency' and *[local-name()='artifactId' and text()='$dep']]" --type elem -n scope -v "$scopeEffective" pom.xml
                else
                    #update
                    xmlstarlet ed -L -P -u "//*[local-name()='project']/*[local-name()='dependencies']/*[local-name()='dependency' and *[local-name()='artifactId' and text()='$dep']]/*[local-name()='scope']" -v "$scopeEffective" pom.xml
                fi
                if [ ! -z "$differentScopes" ]; then
                    differentScopes=$differentScopes$'\n'$dep$'\n'"\"$scope\" != \"$scopeEffective\""
                else
                    differentScopes=$differentScopes$$dep$'\n'"\"$scope\" != \"$scopeEffective\""
                fi
            fi
        done
        IFS=$OlfIFS
        #write down all changed scopes
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
