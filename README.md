# mavenScopeChecker
This basic script checks wheter the dependencyManagement section changes the scope of artifacts and if yes then it changes the scope in the dependencies section according to the scope which is set in the dependencyManagement section.

Usage: ./findChangedScope.sh path_to_project

path_to_project has to be an absolute path to the top-level pom of the project.
