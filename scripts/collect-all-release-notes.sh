#!/usr/bin/env bash

MINORS=${MINORS:-"v1.33 v1.34 v1.35 v1.36"}
PRIME_MINORS=${PRIME_MINORS:-"v1.32"}

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

function convert_warning_blockquotes() {
    local file=$1
    perl -i -p0e 's#^> \[!WARNING\]\r?\n((?:^>.*\r?\n?)*)#
        do {
            my $body = $1;
            $body =~ s/^> ?//mg;
            $body =~ s/\r//g;
            $body =~ s/^\s+|\s+$//g;
            my $title = "Warning";
            if ($body =~ s/^\*\*(.+?)\*\*\r?\n?//) {
                $title = $1;
            }
            ":::warning $title\n$body\n:::\n";
        }
    #gems' "${file}"
}

function process_minor() {
    local minor=$1
    local directory=$2
    local is_prime_minor=0
    product=rke2
    file=$directory/${minor}.X.md
    new_table_rows=$(mktemp)
    new_release_notes=$(mktemp)
    processed_new=0
    latest_existing_patch=""

    if [ -f "${file}" ]; then
        latest_existing_patch=$(grep -m1 '^## Release \[' "${file}" | sed -n 's/^## Release \[\([^]]*\)\].*/\1/p')
    fi

    case " ${PRIME_MINORS} " in
        *" ${minor} "*) is_prime_minor=1 ;;
    esac

    for patch in $(gh release list -R "rancher/${product}" --exclude-drafts --exclude-pre-releases --limit=1000 | awk -F '\t' '{ print $3 }' | grep ^"${minor}"); do
        # Release list is newest-first. Once we hit the current top release, older ones are already present.
        if [ -n "${latest_existing_patch}" ] && [ "${patch}" = "${latest_existing_patch}" ]; then
            break
        fi

        publish_date=$(gh release view "${patch}" -R "rancher/${product}" --json publishedAt -q '.publishedAt' | awk -F'T' '{ print $1 }')
        raw_body=$(gh release view "${patch}" -R "rancher/${product}" --json body -q '.body')
        # Use a chart-stripped body for top summary table extraction.
        table_body=$(perl -0777 -pe 's/(## Charts Versions).*?\n(## Packaged Component Versions)/$2/ms' <<< "$raw_body")
        # Keep Charts Versions in the rendered release notes, but drop all content from
        # Packaged Component Versions onward.
        release_body=$(perl -0777 -pe 's/^## Packaged Component Versions.*\z//ms' <<< "$raw_body")
        # Extract from each release notes the component table, building a single table with all the components
        process_cni_table "$table_body"

        patch_display="${patch}"
        if [ "${is_prime_minor}" -eq 1 ]; then
            patch_display="${patch}\\*"
        fi

        row="| [${patch_display}](${minor}.X.md#release-$(gen_md_link $patch)) | $(date +"%b %d %Y" -d "${publish_date}")"
        while IFS= read -r column; do
            row+="| $column "
        done < <(echo "$table_body"  | grep "^|" | tail -n +3 | head -9 | awk -F'|' '{ print $3 }')
        row+="${CNI_ROWS}"
        echo "$row" >> "${new_table_rows}"

        release_tmp=$(mktemp)
        echo "# Release ${patch}" >> "${release_tmp}"
        echo "$release_body" >> "${release_tmp}"
        echo "-----" >> "${release_tmp}"
        # Add extra levels for Docusaurus Sidebar and link to GH release page
        sed -i 's/^# Release \(.*\)/## Release [\1](https:\/\/github.com\/rancher\/rke2\/releases\/tag\/\1)/' "${release_tmp}"
        sed -i 's/^## Changes since/### Changes since/' "${release_tmp}"
        # Convert GitHub blockquote warning alert to Docusaurus warning admonition.
        convert_warning_blockquotes "${release_tmp}"

        # Wrap Important Notes in a Warning block
        perl -i -p0e 's/\*\*Important Notes\*\*(.*?)###/:::warning Important Notes\n$1\n:::\n\n###/s' "${release_tmp}"
        cat "${release_tmp}" >> "${new_release_notes}"
        rm -f "${release_tmp}"
        processed_new=$((processed_new + 1))
    done

    if [ "${processed_new}" -eq 0 ]; then
        rm -f "${new_table_rows}" "${new_release_notes}"
        echo "No new release notes for ${product} ${minor}"
        return
    fi

    if [ ! -f "${file}" ]; then
        first_patch=$(head -n1 "${new_table_rows}" | sed -n "s/^| \[\([^]]*\)\].*/\1/p")
        first_raw_body=$(gh release view "${first_patch}" -R "rancher/${product}" --json body -q '.body')
        first_table_body=$(perl -0777 -pe 's/(## Charts Versions).*?\n(## Packaged Component Versions)/$2/ms' <<< "$first_raw_body")
        process_cni_table "$first_table_body"

        title="---\nhide_table_of_contents: true\nsidebar_position: 0\ntitle: ${minor}.X\n---\n\n"
        upgrade_link="[Urgent Upgrade Notes](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-${minor:1}.md#urgent-upgrade-notes)"
        upgrade_warning=":::warning Upgrade Notice\nBefore upgrading from earlier releases, be sure to read the Kubernetes ${upgrade_link}.\n:::\n"
        wide_container_table="<div className=\"wide-table-container\">"

        {
            echo -e "${title}"
            echo -e "${upgrade_warning}"
            echo -e "${wide_container_table}\n"
            echo -n "| Version | Release date "
            echo "$first_table_body" | grep "^|" | tail -n +3 | head -9 | awk -F'|' '{ print $2 }' | while read -r column; do echo -n "| $column "; done
            echo "${CNI_HEADERS}"
            for i in {0..9}; do echo -n "| ----- "; done
            echo "${CNI_SEPARATORS}"
            cat "${new_table_rows}"
            echo -e "\n</div>\n\n<br />\n"
            cat "${new_release_notes}"
        } > "${file}"
    else
        rke2tmp=$(mktemp)
        awk -v rows_file="${new_table_rows}" -v notes_file="${new_release_notes}" '
            {
                print
                if (!rows_inserted && $0 ~ /^\| ----- /) {
                    while ((getline line < rows_file) > 0) print line
                    close(rows_file)
                    rows_inserted=1
                }
                if (!notes_inserted && $0 ~ /^<br \/>$/) {
                    print ""
                    while ((getline line < notes_file) > 0) print line
                    close(notes_file)
                    notes_inserted=1
                }
            }
            END {
                if (!notes_inserted) {
                    print ""
                    while ((getline line < notes_file) > 0) print line
                    close(notes_file)
                }
            }
        ' "${file}" > "${rke2tmp}" && mv "${rke2tmp}" "${file}"

        # If this is now a prime minor, we need to add a note about it below the top table
        if [ "${is_prime_minor}" -eq 1 ] && ! grep -q '^\\\* PRIME Only Release$' "${file}"; then
            sed -i "0,/^<br \/>/s/^<br \/>/\\\\* PRIME Only Release\n\n<br \/>/" "${file}"
        fi

    fi

    # gh release produces crlf line endings, convert to lf
    dos2unix "${file}"
    rm -f "${new_table_rows}" "${new_release_notes}"
    echo "Collected release notes for ${product} ${minor}"
}

for minor in $MINORS; do
    process_minor "${minor}" "docs/release-notes" &
done

for minor in $PRIME_MINORS; do
    process_minor "${minor}" "docs/release-notes-old" &
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
