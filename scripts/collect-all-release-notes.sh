#!/usr/bin/env bash
function gen_md_link()
{
    release_link=$(echo $1 | tr '[:upper:]' '[:lower:]' | sed -e 's/ /-/g' -e 's/\.//g' -e 's/+//g')
    echo "${release_link}"
}

MINORS=${MINORS:-"v1.25 v1.26 v1.27 v1.28"}

for minor in $MINORS; do
    product=rke2
    global_table=$(mktemp)
    previous=""
    file=docs/release-notes/${minor}.X.md
    for patch in $(gh release list -R "rancher/${product}" --exclude-drafts --exclude-pre-releases --limit=1000 | awk -F '\t' '{ print $3 }' | grep ^"${minor}"); do
        publish_date=$(gh release view "${patch}" -R "rancher/${product}" --json publishedAt -q '.publishedAt' | awk -F'T' '{ print $1 }')
        echo "# Release ${patch}" >> "${file}"
        gh release view "${patch}" -R "rancher/${product}" --json body -q '.body' >> "${file}"
        echo "-----" >> "${file}"
        body=$(gh release view "${patch}" -R "rancher/${product}" --json body -q '.body')
        # Extract from each release notes the component table, building a single table with all the components
        if [ -z "${previous}" ]; then
            title="---\nhide_table_of_contents: true\n---\n\n# ${minor}.X\n"
            echo -e "${title}" >> $global_table
            upgrade_link="[Urgent Upgrade Notes](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-${minor:1}.md#urgent-upgrade-notes)"
            upgrade_warning=":::warning Upgrade Notice\nBefore upgrading from earlier releases, be sure to read the Kubernetes ${upgrade_link}.\n:::\n"
            echo -e "${upgrade_warning}" >> $global_table
            echo -n "| Version | Release date " >> $global_table
            # RKE2 Core Components
            echo "$body"  | grep "^|" | tail +3 | head -8 | awk -F'|' '{ print $2 }' | while read column; do echo -n "| $column " >> $global_table; done
            # RKE2 CNIs
            echo "$body"  | grep "^|" | tail -4 | awk -F'|' '{ print $2 }' | while read column; do echo -n "| $column " >> $global_table; done
            echo " |" >> $global_table
            for i in {0..13}; do echo -n "| ----- " >> $global_table; done
            echo " |" >> $global_table
        fi
        echo -n "| [${patch}](${minor}.X.md#release-$(gen_md_link $patch)) | $(date +"%b %d %Y" -d "${publish_date}")" >> $global_table
        echo "$body"  | grep "^|" | tail +3 | head -8 | awk -F'|' '{ print $3 }' | while read column; do echo -n "| $column " >> $global_table; done
        echo "$body"  | grep "^|" | tail -4 | awk -F'|' '{ print $3 }' | while read column; do echo -n "| $column " >> $global_table; done
        echo " |" >> $global_table
        previous=$patch
        # Remove the component table from each individual release notes
        perl -i -p0e 's/^## Packaged Component Versions.*?^-----/-----/gms' "${file}"
        # Add extra levels for Docusaurus Sidebar and link to GH release page
        sed -i 's/^# Release \(.*\)/## Release [\1](https:\/\/github.com\/rancher\/rke2\/releases\/tag\/\1)/' "${file}"
        sed -i 's/^## Changes since/### Changes since/' "${file}"
        # Wrap Important Notes in a Warning block
        perl -i -p0e 's/\*\*Important Notes\*\*(.*?)###/:::warning Important Notes\n$1\n:::\n\n###/s' "${file}"
    done
    echo -e "\n<br />\n" >> $global_table
    # Append the global component and version table
    rke2tmp=$(mktemp)
    cat $global_table "${file}" > $rke2tmp && mv $rke2tmp "${file}"
    echo "Collected release notes for ${product} ${minor}"
done
