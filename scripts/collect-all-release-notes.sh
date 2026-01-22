#!/usr/bin/env bash

MINORS=${MINORS:-"v1.32 v1.33 v1.34 v1.35"}

function gen_md_link()
{
    release_link=$(echo $1 | tr '[:upper:]' '[:lower:]' | sed -e 's/ /-/g' -e 's/\.//g' -e 's/+//g')
    echo "${release_link}"
}

# This function extract any CNI table, dealing with the different number of CNIs in each release
# and the different column names that are used across releases.
# We transpose the table to have the CNIs as columns and the versions as rows.
function process_cni_table {

    # Read the markdown table into an array
    mapfile -t lines <<< "$(echo "$1" | sed -n '/### Available CNIs/,/^\s*$/p' | tail -n +4)"

    # Initialize arrays for the headers and rows
    declare -a headers
    declare -a rows

    # Process each line
    for line in "${lines[@]}"; do
        # Split the line into fields
        IFS='|' read -r -a fields <<< "$line"

        # Remove leading and trailing whitespace from each field
        for i in "${!fields[@]}"; do
            fields[i]=$(echo "${fields[i]}" | sed 's/^\s*//;s/\s*$//')
        done

        # Add the fields to the rows array
        headers+=("${fields[1]}")
        rows+=("${fields[2]}")
    done

    # Build the headers, the last header is empty, capping the table
    CNI_HEADERS=""
    for header in "${headers[@]}"; do
        CNI_HEADERS+="| $header "
    done

    # Build the separator
    CNI_SEPARATORS="|"
    for ((i=1; i<=${#headers[@]}; i++)); do
        CNI_SEPARATORS+=" ----- |"
    done

    # Build the rows, the last row is empty, capping the table
    CNI_ROWS=""
    for ((i=0; i<${#rows[@]}; i++)); do
        CNI_ROWS+="| ${rows[i]} "
    done
}

function process_minor() {
    local minor=$1
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
        # Some releases have a Chart Versions Table. Strip it out, we don't include it in the release notes
        body=$(perl -0777 -pe 's/(## Charts Versions).*?\n(## Packaged Component Versions)/$2/ms' <<< "$body")
        # Extract from each release notes the component table, building a single table with all the components
        process_cni_table "$body"
        if [ -z "${previous}" ]; then
            title="---\nhide_table_of_contents: true\nsidebar_position: 0\ntitle: ${minor}.X\n---\n\n"
            echo -e "${title}" >> $global_table
            upgrade_link="[Urgent Upgrade Notes](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-${minor:1}.md#urgent-upgrade-notes)"
            upgrade_warning=":::warning Upgrade Notice\nBefore upgrading from earlier releases, be sure to read the Kubernetes ${upgrade_link}.\n:::\n"
            echo -e "${upgrade_warning}" >> $global_table
            echo -n "| Version | Release date " >> $global_table
            # RKE2 Core Components
            echo "$body"  | grep "^|" | tail +3 | head -8 | awk -F'|' '{ print $2 }' | while read column; do echo -n "| $column " >> $global_table; done
            echo $CNI_HEADERS >> $global_table
            for i in {0..8}; do echo -n "| ----- " >> $global_table; done
            echo $CNI_SEPARATORS >> $global_table
        fi
        echo -n "| [${patch}](${minor}.X.md#release-$(gen_md_link $patch)) | $(date +"%b %d %Y" -d "${publish_date}")" >> $global_table
        echo "$body"  | grep "^|" | tail +3 | head -8 | awk -F'|' '{ print $3 }' | while read column; do echo -n "| $column " >> $global_table; done
        echo $CNI_ROWS >> $global_table
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
    # gh release produces crlf line endings, convert to lf
    dos2unix "${file}"
    echo "Collected release notes for ${product} ${minor}"
}

for minor in $MINORS; do
    process_minor "${minor}" &
done

wait

# For all the releases, order the release notes in reverse numerical order
ITER=1
echo "Reordering release notes in sidebar"
for file in $(ls -r docs/release-notes/v1.*.X.md); do
   # Add sidebar_position: $ITER to each release notes
    sed -i "s/^sidebar_position:.*/sidebar_position: $ITER/" "${file}"
    ITER=$((ITER+1))
done

ITER=1
echo "Reordering older release notes in sidebar"
for file in $(ls -r docs/release-notes-old/v1.*.X.md); do
    sed -i "s/^sidebar_position:.*/sidebar_position: $ITER/" "${file}"
    ITER=$((ITER+1))
done