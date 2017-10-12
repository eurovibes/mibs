#! /bin/bash

export GPG_TTY=$(tty)

RELEASEBRANCH="master"
DRAFTBRANCH="draft"
MASTERMIB=EUROVIBES-MIB
KEYID="045CAD656AAA12DD77E8BE718CDF827C4CD3D2D3"

function replace_rev {
    LASTUPDATE=$(TZ=UTC git log --date=format-local:"%Y%m%d%H%MZ" -n 1 \
		   --pretty=format:"%cd" "$1")

    sed -i "s/LAST-UPDATED.*$/LAST-UPDATED \"$LASTUPDATE\"/" "$1"

    TZ=UTC git log \
      --date=format-local:"%Y%m%d%H%MZ" \
      --pretty=format:'-- %H%nREVISION ""%cd""%nDESCRIPTION%n""%s%n%b""%n' \
      "$1" | \
	sed -e 's/[\"]\([^\"]\)/\1/g' -e 's/[\"]\+/\"/g' > "${1}.rev"

    ./updaterev "$1" > "${1}.new"
    mv "${1}.new" "$1"
    rm "${1}.rev"
}

if [ x"$1" == x ]
then
    echo "usage: $0 <releasename>"
    exit 1
fi

CURRENTBRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ "$CURRENTBRANCH" != "$DRAFTBRANCH" ]
then
    echo "Not in branch \"$DRAFTBRANCH\". Abort."
    exit 1
fi

UNTRACKED=$(git status --porcelain | grep -- '-MIB')

if [ x"$UNTRACKED" != x ]
then
    echo "Untracked changes in MIB files. Abort."
    exit 1
fi

for MIB in $(find . -type f -name '*-MIB')
do
    replace_rev "$MIB"
done

# Master MIB need the complete History. Recreate revision infos.
replace_rev "$MASTERMIB"

git diff "$RELEASEBRANCH" > release.patch
git reset --hard
git checkout "$RELEASEBRANCH"
patch -p1 < release.patch
awk '/\+\+\+/{gsub("b/", ""); print "git add " $2}' release.patch | sh
rm release.patch
git commit -a -s -m "release $1"
git tag -u "$KEYID" -m "release $1" "$1"
git checkout "$CURRENTBRANCH"
