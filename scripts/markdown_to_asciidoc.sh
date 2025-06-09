#!/bin/bash
set -e

# Requires kramdoc to be installed.
# See https://github.com/asciidoctor/kramdown-asciidoc

DOCS_DIR="./docs"
ASCII_DIR="./asciidoc"

# Converts MDX <Tabs> and <TabItem> tags into AsciiDoc format.
# Converts admonitions to AsciiDoc equivalents.
# Converts HTML Collapsible sections to AsciiDoc equivalents.
# We support tabs and admonitions but kramdoc does not, so they are commented out with "//zz" 
# which we will remove after the conversion. 
preprocess_adoc() {
    local input_file="$1"
    local temp_file="${input_file%.md}.tmp"

    # Admonition equivalents in AsciiDoc.
    # note -> [NOTE]
    # tip -> [TIP]
    # info -> [IMPORTANT]
    # warning -> [CAUTION]
    # danger -> [Warning]

    while IFS= read -r line; do
        case "$line" in
            '<Tabs groupId="'*)
                group_id=$(echo "$line" | sed -n "s/.*<Tabs groupId=[\"']\([^\"']*\)[\"'].*/\1/p")
                echo "//zz[tabs,sync-group-id=${group_id}]"
                echo "//zz====="
                ;;
            '<Tabs>'*|*'<Tabs '*'>'*)
                echo "//zz[tabs]"
                echo "//zz====="
                ;;
            '</Tabs>'*)
                echo "//zz====="
                ;;
            *'<TabItem'*)
                # Extract the 'value' attribute using sed.
                title=$(echo "$line" | sed -n "s/.*<TabItem value=[\"']\([^\"']*\)[\"'].*/\1/p")
                echo "//zz${title}::"
                echo "//zz+"
                echo "//zz--"
                ;;
            '</TabItem>'*)
                echo "//zz--"
                echo ""
                ;;
            ':::note'*)
                echo "//zz[NOTE]"
                echo "//zz===="
                ;;
            ':::tip'*)
                echo "//zz[TIP]"
                echo "//zz===="
                ;;
            ':::info'*)
                title=$(echo "$line" | sed -n "s/.*:::info[ ]*\(.*\)/\1/p")
                if [[ -n "$title" ]]; then
                    printf "//zz[IMPORTANT]\n//zz.%s\n//zz====\n" "$title"
                else
                    printf "//zz[IMPORTANT]\n//zz====\n"
                fi
            ;;
            ':::warning'*)
                title=$(echo "$line" | sed -n "s/.*:::warning[ ]*\(.*\)/\1/p")
                if [[ -n "$title" ]]; then
                    printf "//zz[CAUTION]\n//zz.%s\n//zz====\n", "$title"
                else
                    printf "//zz[CAUTION]\n//zz====\n"
                fi
                ;;
            ':::danger'*)
                echo "//zz[WARNING]"
                echo "//zz===="
                ;;
            ':::')
                # Match the end of an admonition block.
                echo "//zz===="
                ;;
            '<details>'*)
                # Convert HTML collapsible sections to AsciiDoc equivalents.
                # We will use a custom tag for collapsible sections.
                echo "//zz[%collapsible]"
                ;;
            '<summary>'*)
                # Extract the summary text and use it as the title for the collapsible section.
                summary_text=$(echo "$line" | sed -n "s/.*<summary>\(.*\)<\/summary>.*/\1/p")
                if [[ -n "$summary_text" ]]; then
                    echo "//zz.$summary_text"
                fi
                echo "//zz======"
                ;;
            '</details>'*)
                echo "//zz======"
                ;;
            # Any other line is passed through as-is.
            *)
                echo "$line"
                ;;
        esac
    done < "$input_file" > "$temp_file"

    # Remove all docusaurous file attributes.
    sed -i '/slug:.*/d' "$temp_file"
    sed -i '/sidebar_position:.*/d' "$temp_file"
    sed -i '/hide_table_of_contents:.*/d' "$temp_file"
    sed -i '/sidebar_label:.*/d' "$temp_file"

    # Convert docuasarous title attribute to a level 1 header that kramdoc can handle.
    sed -i -e '/^---$/d' -e 's/^title: \(.*\)/# \1/' "$temp_file"

    # Return the path of the temporary file for the next step.
    echo "$temp_file"
}

postprocess_adoc() {
    local adoc_file="$1"
    # Remove the "//zz" prefix from the tab blocks and admonitions that we hid from kramdoc
    sed -i 's|//zz||g' "$adoc_file"

    # Remove github special image tags and dark mode images
    # Antora does not support these.
    sed -i 's|#gh-light-mode-only||g' "$adoc_file"
    sed -i '/#gh-dark-mode-only/d' "$adoc_file"

    # Fix xrefs that are not relative to the current file.
    # xref:automated_upgrade.adoc => xref:./automated_upgrade.adoc
    sed -i 's|xref:\([a-zA-Z0-9_-]\+\.adoc\)|xref:./\1|g' "$adoc_file"
    
    # Assume images are handled by antora setup, with a root /images/
    # automatically configured by the antora playbook.
    sed -i 's|image::/img/|image::|g' "$adoc_file"
    sed -i 's|image:/img/|image:|g' "$adoc_file"
      
    # Fix all internal header references. Antora expects _foo_bar format
    # but kramdoc keeps the foo-bar format.
    # <<foo-bar,The Foo Bar>> => <<foo_bar,The Foo Bar>>
    perl -i -pe 's|(<<)([^,>]*)|$1 . do { my $x = $2; $x =~ s/-/_/g; $x }|ge' "$adoc_file"
    sed -i 's|<<\([a-zA-Z0-9]\)|<<_\1|g' "$adoc_file"

}


mkdir -p "$ASCII_DIR"

SKIP_FILES=("adr" "migration.md" "cis_self_assessment12" "cis_self_assessment16" )

find "$DOCS_DIR" -type f -name "*.md" | while read -r file; do
    
    skip=0
    for pattern in "${SKIP_FILES[@]}"; do
        if [[ "$file" == *"$pattern"* ]]; then
            skip=1
            break
        fi
    done
    if [[ $skip -eq 1 ]]; then
        echo "Skipping file: $file"
        continue
    fi

    echo "-------------------------------------"
    echo "Processing Markdown file: $file"

    # Preprocess the file to protect tab, admonition, and collapsible elements.
    temp_file_path=$(preprocess_adoc "$file")

    # Generate the same directory structure but with the .md extension replaced by .adoc.
    asciidoc_file="$ASCII_DIR${file#"$DOCS_DIR"}"
    asciidoc_file="${asciidoc_file%.md}.adoc"
    
    mkdir -p "$(dirname "$asciidoc_file")"

    kramdoc "$temp_file_path" -o "$asciidoc_file"

    rm "$temp_file_path"

    # Uncomment preprocessed elements and fix additional issues.
    postprocess_adoc "$asciidoc_file"
    
    echo "Processed: $asciidoc_file"
done
