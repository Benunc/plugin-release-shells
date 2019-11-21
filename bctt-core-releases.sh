#!/bin/sh

# By Mike Jolley, based on work by Barry Kooij ;)
# I (Ben Meredith) then forked it from GiveWP, and added my own flair.
# License: GPL v3

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>

# ----- START EDITING HERE -----

# THE GITHUB ACCESS TOKEN, GENERATE ONE AT: https://github.com/settings/tokens
GITHUB_ACCESS_TOKEN=""

# The slug of your WordPress.org plugin
PLUGIN_SLUG="better-click-to-tweet"

# GITHUB user who owns the repo
GITHUB_REPO_OWNER="Benunc"

# GITHUB Repository name
GITHUB_REPO_NAME="better-click-to-tweet"

# ----- STOP EDITING HERE -----

set -e
clear

# ASK INFO
echo "--------------------------------------------"
echo "      Github to WordPress.org RELEASER      "
echo "--------------------------------------------"
read -p "TAG AND RELEASE VERSION: " VERSION
echo "--------------------------------------------"
echo ""
read -p "Type LIVE to release an actual release on GitHub and WordPress.org" LIVE
echo ""
echo "Before continuing, confirm that you have done the following :)"
echo ""
read -p " - Added a changelog for "${VERSION}"?"
read -p " - Set version in the readme.txt file to "${VERSION}"?"
read -p " - Set version in the main file to "${VERSION}"?"
read -p " - Set version in the CONSTANT in the main file to "${VERSION}"?"
read -p " - Set stable tag in the readme.txt file to "${VERSION}"?"
read -p " - Committed all changes up to GITHUB?"
read -p " - Did you just lie to me on any of those questions regarding version "${VERSION}"?"
echo ""
read -p "PRESS [ENTER] TO BEGIN RELEASING "${VERSION}
clear

# VARS
ROOT_PATH=$(pwd)"/"
TEMP_GITHUB_REPO=${PLUGIN_SLUG}"-git"
TEMP_SVN_REPO=${PLUGIN_SLUG}"-svn"
SVN_REPO="http://plugins.svn.wordpress.org/"${PLUGIN_SLUG}"/"
GIT_REPO="git@github.com:"${GITHUB_REPO_OWNER}"/"${GITHUB_REPO_NAME}".git"

# DELETE OLD TEMP DIRS
rm -Rf $ROOT_PATH$TEMP_GITHUB_REPO

# CHECKOUT SVN DIR IF NOT EXISTS
if [ "$LIVE" = "LIVE" ]
then
	if [[ ! -d $TEMP_SVN_REPO ]];
	then
		echo "Checking out WordPress.org plugin repository"
		svn checkout $SVN_REPO $TEMP_SVN_REPO || { echo "Unable to checkout repo."; exit 1; }
	fi
fi

# CLONE GIT DIR
echo "Cloning GIT repository from GITHUB"
git clone --progress $GIT_REPO $TEMP_GITHUB_REPO || { echo "Unable to clone repo."; exit 1; }

# MOVE INTO GIT DIR
cd $ROOT_PATH$TEMP_GITHUB_REPO

# LIST BRANCHES
clear
git fetch origin
echo "WHICH BRANCH DO YOU WISH TO DEPLOY?"
git branch -r || { echo "Unable to list branches."; exit 1; }
echo ""
read -p "origin/" BRANCH

# Switch Branch
echo "Switching to branch"
git checkout ${BRANCH} || { echo "Unable to checkout branch."; exit 1; }

echo ""
read -p "PRESS [ENTER] TO DEPLOY BRANCH "${BRANCH}

# RUN COMPOSER
if [ -f composer.json ]; then
    composer install
fi

if [ -f package.json ]; then
    npm install
    npm run build
fi

# Checking for git submodules
if [ -f .gitmodules ];
then
echo "Submodule found. Updating"
git submodule init
git submodule update
else
echo "No submodule exists"
fi

if [ "$LIVE" = "LIVE" ]
then

    # PROMPT USER
    echo ""
    read -p "Press [ENTER] to commit release "${VERSION}" to GitHub"
    echo ""

    # CREATE THE GITHUB RELEASE
    echo "Creating GitHub tag and release"
    git tag -a "v"${VERSION} -m "Tagging version: $VERSION." -m "The ZIP and TAR.GZ here are not production-ready." -m "Build by checking out the release and running composer install, npm install, and npm run build."

    git push origin --tags # push tags to remote
    echo "";
fi

# REMOVE UNWANTED FILES & FOLDERS
echo "Removing unwanted files..."
rm -Rf assets/src
rm -Rf tests
rm -Rf bower
rm -Rf tmp
rm -Rf node_modules
rm -Rf apigen
rm -Rf .idea
rm -Rf .github
rm -Rf vendor

# Hidden Files
rm -rf .bowerrc
rm -rf .babelrc
rm -rf .scrutinizer.yml
rm -rf .travis.yml
rm -rf .CONTRIBUTING.md
rm -rf .gitattributes
rm -rf .gitignore
rm -rf .gitmodules
rm -rf .editorconfig
rm -rf .travis.yml
rm -rf .jscrsrc
rm -rf .jshintrc
rm -rf .eslintrc
rm -rf .eslintignore
rm -rf .nvmrc

# Other Files
rm -rf bower.json
rm -rf composer.json
rm -rf composer.lock
rm -rf package.json
rm -rf package-lock.json
rm -rf Gruntfile.js
rm -rf GulpFile.js
rm -rf gulpfile.js
rm -rf grunt-instructions.md
rm -rf composer.json
rm -rf phpunit.xml
rm -rf phpunit.xml.dist
rm -rf phpcs.ruleset.xml
rm -rf phpcs.xml
rm -rf LICENSE
rm -rf LICENSE.txt
rm -rf README.md
rm -rf CHANGELOG.md
rm -rf CODE_OF_CONDUCT.md
rm -rf readme.md
rm -rf postcss.config.js
rm -rf webpack.config.js
rm -rf docker-compose.yml
rm -Rf .git

wait
echo "All cleaned! Proceeding..."

if [ "$LIVE" = "LIVE" ]
then
	# MOVE INTO SVN DIR
	cd $ROOT_PATH$TEMP_SVN_REPO

	# UPDATE SVN
	echo "Updating SVN"
	svn update || { echo "Unable to update SVN."; exit 1; }

	# DELETE TRUNK
	echo "Replacing trunk"
	rm -Rf trunk/

	# COPY GIT DIR TO TRUNK
	cp -R $ROOT_PATH$TEMP_GITHUB_REPO trunk/

	# DO THE ADD ALL NOT KNOWN FILES UNIX COMMAND
	svn add --force * --auto-props --parents --depth infinity -q

	# DO THE REMOVE ALL DELETED FILES UNIX COMMAND
	MISSING_PATHS=$( svn status | sed -e '/^!/!d' -e 's/^!//' )

	# iterate over filepaths
	for MISSING_PATH in $MISSING_PATHS; do
		svn rm --force "$MISSING_PATH"
	done

	# COPY TRUNK TO TAGS/$VERSION
	echo "Copying trunk to new tag"
	svn copy trunk tags/${VERSION} || { echo "Unable to create tag."; exit 1; }

	# DO SVN COMMIT
	clear
	echo "Showing SVN status"
	svn status

	# PROMPT USER
	echo ""
	read -p "PRESS [ENTER] TO COMMIT RELEASE "${VERSION}" TO WORDPRESS.ORG AND GITHUB"
	echo ""

	# CREATE THE GITHUB RELEASE
	echo "Creating GITHUB release"
	API_JSON=$(printf '{ "tag_name": "%s","target_commitish": "%s","name": "%s", "body": "Release of version %s", "draft": false, "prerelease": false }' $VERSION $BRANCH $VERSION $VERSION)
	RESULT=$(curl --data "${API_JSON}" https://api.github.com/repos/${GITHUB_REPO_OWNER}/${GITHUB_REPO_NAME}/releases?access_token=${GITHUB_ACCESS_TOKEN})

	# DEPLOY
	echo ""
	echo "Committing to WordPress.org...this may take a while..."
	svn commit -m "Release "${VERSION}", see readme.txt for the changelog." || { echo "Unable to commit."; exit 1; }
fi


sleep 3
clear
read -p "Check to make sure .git is removed"
echo ""

# Create the Zip File
echo "Creating zip package..."
cd "$ROOT_PATH"
mv "$TEMP_GITHUB_REPO" "$PLUGIN_SLUG" #Rename cleaned repo

read -p "check renamed repo"
echo ""
wait
zip -r "$PLUGIN_SLUG".zip "$PLUGIN_SLUG" #Zip it
wait

mv "$PLUGIN_SLUG" "$TEMP_GITHUB_REPO" #Rename back to temp dir
wait
echo "ZIP package created"
echo ""
read -p "check ZIP"

# REMOVE THE TEMP DIRS
echo "CLEANING UP"
rm -Rf $ROOT_PATH$TEMP_GITHUB_REPO
rm -Rf $ROOT_PATH$TEMP_SVN_REPO

# DONE, BYE
echo "RELEASER DONE :D"
