#!/bin/bash

# Function to prompt for input if not supplied
prompt_for_input() {
    local prompt_message=$1
    local default_value=$2
    local input_value

    read -p "$prompt_message [$default_value]: " input_value
    echo "${input_value:-$default_value}"
}

# Function to show a progress indicator
show_progress() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='|/-\'
    echo -n "$message"
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    echo " Done."
}

# Check if extension and months are supplied as parameters, if not prompt for them
extension=${1:-$(prompt_for_input "Enter the file extension to filter by (e.g., .java)" ".java")}
months=${2:-$(prompt_for_input "Enter the number of months to look back" "6")}

# Generate package change counts and store in a variable
echo "Collecting package changes..."
package_changes=$(git log --since="$months.months.ago" --pretty=format: --name-only \
    | sed '/^\s*$/d' \
    | grep -E ".*\\$extension$" \
    | awk -F'/' '{
        path=""
        for(i=1; i<NF; i++) {
            path = (i==1 ? "" : path "/") $i
        }
        print path
    }' \
    | sort \
    | uniq -c)

# Create a temporary file to store folder counts
temp_file=$(mktemp)

# Aggregate counts for parent folders
echo "Aggregating folder counts..."
while read -r line; do
    count=$(echo "$line" | awk '{print $1}')
    path=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ //')

    IFS='/' read -r -a parts <<< "$path"
    for (( i=1; i<=${#parts[@]}; i++ )); do
        subpath=$(IFS='/'; echo "${parts[*]:0:i}")
        echo "$count $subpath" >> "$temp_file"
    done
done <<< "$package_changes"

# Sum up the counts for each folder
echo "Summing up folder counts..."
sort "$temp_file" | awk '{counts[$2]+=$1} END {for (path in counts) print counts[path], path}' > "$temp_file.sorted"

# Read the sorted counts into an array
declare -a aggregated_tree
max_count=0

# Show progress for reading sorted counts
echo "Reading sorted counts into array..."
while read -r line; do
    count=$(echo "$line" | awk '{print $1}')
    path=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ //')
    aggregated_tree+=("$count $path")
    (( count > max_count )) && max_count=$count
done < "$temp_file.sorted"

# Cleanup temporary files
rm "$temp_file" "$temp_file.sorted"

# Sort the array alphabetically by path
IFS=$'\n' aggregated_tree=($(sort -k2 <<<"${aggregated_tree[*]}"))
unset IFS

# Function to calculate the color based on the count using a more refined logarithmic scale
calculate_color() {
    local count=$1
    local max=$2
    local ratio=$(echo "scale=2; l($count+1)/l($max+1)" | bc -l)

    local red=0
    local green=0

    if (( $(echo "$ratio < 0.33" | bc -l) )); then
        # Transition from green to yellow
        green=255
        red=$(echo "scale=0; 765 * $ratio / 1" | bc)
    elif (( $(echo "$ratio < 0.66" | bc -l) )); then
        # Transition from yellow to orange
        red=255
        green=$(echo "scale=0; 255 - 510 * ($ratio - 0.33) / 1" | bc)
    else
        # Transition from orange to red
        red=255
        green=0
        red=$(echo "scale=0; 255 - 255 * ($ratio - 0.66) / 1" | bc)
    fi

    echo "$red,$green,0"
}

# Function to calculate brightness and determine appropriate text color
calculate_text_color() {
    local r=$1
    local g=$2
    local b=$3
    local brightness=$(echo "($r * 299 + $g * 587 + $b * 114) / 1000" | bc)

    if (( brightness > 125 )); then
        echo "black"
    else
        echo "white"
    fi
}

# Generate the HTML
generate_html() {
    local html="<html><head><style>
    body { font-family: Arial, sans-serif; }
    .package { padding: 5px; margin: 2px 0; border-radius: 5px; cursor: pointer; }
    .collapsible { display: none; }
    .icon { display: inline-block; width: 12px; height: 12px; margin-right: 5px; }
    .icon.collapsible::before { content: '▶'; }
    .icon.expanded::before { content: '▼'; }
    h1 { text-align: center; }
    </style>
    <script>
    function toggleCollapse(element) {
        const collapsible = element.nextElementSibling;
        const icon = element.querySelector('.icon');
        if (collapsible.style.display === 'block') {
            collapsible.style.display = 'none';
            icon.classList.remove('expanded');
            icon.classList.add('collapsible');
        } else {
            collapsible.style.display = 'block';
            icon.classList.remove('collapsible');
            icon.classList.add('expanded');
        }
    }
    </script></head><body>\n"

    html+="<h1>Git directory changes report</h1>\n"
    html+="<h2>Filtered by extension: $extension</h2>\n"
    html+="<h2>Changes in the last $months months</h2>\n"

    local previous_indent=0
    local indent_diff=0
    local opened_collapsible=false
    local previous_path=""
    for entry in "${aggregated_tree[@]}"; do
        count=$(echo "$entry" | awk '{print $1}')
        path=$(echo "$entry" | awk '{$1=""; print $0}' | sed 's/^ //')
        local color_rgb=$(calculate_color $count $max_count)
        IFS=',' read -r red green blue <<< "$color_rgb"
        local text_color=$(calculate_text_color $red $green $blue)
        local indent=$(echo "$path" | awk -F'/' '{print NF-1}')
        indent_diff=$(( indent - previous_indent ))

        if (( indent_diff > 0 )); then
            html+="<div class='collapsible' style='margin-left: $((previous_indent * 20))px;'>\n"
            opened_collapsible=true
        elif (( indent_diff < 0 )); then
            for ((i=0; i<-indent_diff; i++)); do
                html+="</div>\n"
            done
        elif (( indent == 0 && opened_collapsible )); then
            html+="</div>\n"
            opened_collapsible=false
        fi

        # Check if there are subitems
        if grep -q "$path/" <<< "${aggregated_tree[*]}"; then
            icon="<span class='icon collapsible'></span>"
        else
            icon="<span class='icon'></span>"
        fi

        html+="<div class='package' style='background-color: rgb($red,$green,$blue); color: $text_color; margin-left: $((indent * 20))px;' onclick='toggleCollapse(this)'>$icon$path ($count)</div>\n"

        previous_indent=$indent
    done

    if $opened_collapsible; then
        html+="</div>\n"
    fi

    html+="</body></html>"
    echo -e "$html"
}

html_content=$(generate_html)

# Write the HTML content to a file
html_file="package_changes.html"
echo -e "$html_content" > "$html_file"

echo "HTML report generated in $html_file"

# Open the HTML report in the default browser
if [[ "$OSTYPE" == "darwin"* ]]; then
    open "$html_file"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    xdg-open "$html_file"
else
    echo "Automatic opening of the browser is not supported on this OS."
fi
