#!/bin/bash

# AUTHOR:
# Brendan Rood
# Last Modified: 1730410058

# USAGE:
# Preforms linear interpolation on electrical consumption data, 
# yielding instantaneous consumption on each hour, on the hour within the bounds of the dataset
# Input data should be a csv of two columns; col1: UNIX EPOCH Timestamp, col2: Electrical Consumption (kWh)
# Input data must be stored in `./data.csv`.
# Output will be written to `./interpolate.csv`



script_dir="$(dirname "$0")" # Get the directory of the script
input_file="$script_dir/data.csv"



# ===== Find start and end of data =====

echo "Determining data bounds ... ";

start_timestamp=$(sort -n -k1 "$input_file" | head -n 1 | awk -F',' '{print $1}');
end_timestamp=$(sort -n -k1 "$input_file" | tail -n 1 | awk -F',' '{print $1}');

start_rounded=$((start_timestamp / 3600)); # do integer division to remove hours and seconds
start_rounded=$((start_rounded * 3600)); # multiply by 3600 to restore to original value (hours and seconds == 0)
start_rounded=$((start_rounded + 3600)); # add 1 hour to round up

end_rounded=$((end_timestamp / 3600)); # do integer division to remove hours and seconds
end_rounded=$((end_rounded * 3600)); # multiply by 3600 to restore to original value (hours and seconds == 0)
end_rounded=$((end_rounded - 0)); # value is already rounded down via truncation

echo "Start of data = $(date -d "@$start_rounded" "+%Y-%m-%d %H:%M:%S")";
echo "End of data = $(date -d "@$end_rounded" "+%Y-%m-%d %H:%M:%S")";

echo "Data bounds found!";



# ===== Generate Polling Intervals =====
echo "Generating polling intervals ... "

current_timestamp=$start_rounded

rm "$script_dir/pollingIntervals.csv" 2>/dev/null
touch "$script_dir/pollingIntervals.csv";

while [ $current_timestamp -lt $end_rounded ]; do
    echo "$current_timestamp" >> "$script_dir/pollingIntervals.csv";
    current_timestamp=$((current_timestamp + 3600));
done

echo "Polling Intervals found!"



# ===== Get needed info for each polling period =====
echo -en "Preparing for interpolation ... "

rm "$script_dir/neededValues.csv" 2>/dev/null
touch "$script_dir/neededValues.csv";

mapfile -t derived < "$script_dir/pollingIntervals.csv"
for ((target=0; target<${#derived[@]}; target++)); do
    x1=0
    y1=0
    x2=0
    y2=0

    # Read the entire input file into a variable
    mapfile -t lines < "$input_file"
   
    for line in "${lines[@]}"; do
        IFS=',' read -r col1 col2 <<< "$line"
        if [[ $col1 -lt ${derived[target]} ]]; then
            x1=$col1
            y1=$(awk "BEGIN { printf \"%.2f\", $col2/1 }")
        fi
    done
 
    for ((i=${#lines[@]}-1; i>=0; i--)); do
        line="${lines[i]}"
        IFS=',' read -r col1 col2 <<< "$line"
        if [[ $col1 -gt ${derived[target]} ]]; then
            x2=$col1
            y2=$(awk "BEGIN { printf \"%.2f\", $col2/1 }")
        fi
    done
 
    result="${derived[target]},$x1,$y1,$x2,$y2"
    echo $result >> "$script_dir/neededValues.csv"
 
    # Update the terminal
    echo -ne "\rPreparing for interpolation ... [$target/${#derived[@]}]"
done
echo -ne "\nPreperation Complete!\n";



# ===== Do Interpolation =====
echo -en "Interpolating ... "

rm "$script_dir/interpolate.csv" 2>/dev/null
touch "$script_dir/interpolate.csv";

mapfile -t lines < "$script_dir/neededValues.csv"
for ((i=0; i<${#lines[@]}; i++)); do
    line="${lines[i]}"
    IFS=',' read -r col1 col2 col3 col4 col5 <<< "$line"
    target=$col1
    smallX=$col2
    smallY=$col3
    largeX=$col4
    largeY=$col5

    # Calculate (y2 - y1) / (x2 - x1)
    slope=$(bc -l <<< "scale=10; ($largeY - $smallY) / ($largeX - $smallX)")

    # Calculate (xt - x1)
    dx=$(( $target - $smallX ))

    # Calculate y1 + slope * dx
    result=$(printf "%.2f" $(bc -l <<< "$smallY + $slope * $dx"))
        
    
    # Write result to file
    result="$target,$result"
    echo $result >> "$script_dir/interpolate.csv";

    # Update Console
    echo -ne "\rInterpolating ... [$i/${#lines[@]}]"
done

echo -en "\nInterpolation Complete\n"

# Add original data back in
#cat $input_file >> "$script_dir/interpolate.csv";
#sort -n -k1 "$script_dir/interpolate.csv" > "$script_dir/interpolate.csv.tmp"
#mv "$script_dir/interpolate.csv.tmp" "$script_dir/interpolate.csv"



# ===== Calculate instanteneous consumption per hour =====
echo -en "Finding hourly instantaneous change ... "
awk -F',' '
    NR == 1 {  # First row
        prev_col2 = $2  # Store col2

        printf "%s,%s,%.2f\n", $1, $2, 0  # data as-is, change is 0
    } 
    NR > 1 {  # Subsequent rows

        # Calculate difference
        diff = $2 - prev_col2

        prev_col2 = $2  # Store col2
        
        # Print original row and difference
        printf "%s,%s,%s\n", $1, $2, diff
    }
' "$script_dir/interpolate.csv" > "$script_dir/interpolate.csv.tmp"
mv "$script_dir/interpolate.csv.tmp" "$script_dir/interpolate.csv"

echo -en "\nHourly instantaneous change found!\n"



# ===== Labeling Hours =====
echo -en "Adding labels ... "
# Read the entire input file into a variable
mapfile -t lines < "$script_dir/interpolate.csv"

for line in "${lines[@]}"; do
    IFS=',' read -r col1 col2 col3 <<< "$line"
    hour=$(date -d @"$col1" +%H)
    date=$(date -d @"$col1" +%Y-%m-%d)

    printf "%s,%s,%s,%s,%s\n" $col1 $col2 $col3 $hour $date >> "$script_dir/interpolate.csv.tmp"
done
mv "$script_dir/interpolate.csv.tmp" "$script_dir/interpolate.csv"

sed -i '1i'"Timestamp,Consumption,InstantaneousChange,Hour,Date" "$script_dir/interpolate.csv"

echo -en "\nLabeling complete!\n"


# ===== Clean up temp files =====
rm "$script_dir/pollingIntervals.csv"
rm "$script_dir/neededValues.csv"
