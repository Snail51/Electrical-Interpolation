# Purpose
 - Starting in the summer of 2024, my family's power bill went up significantly for no apparent reason. I began tracking the electrical consumption of certain circuts in my house, creating a spreadsheet of `<UNIX TIMESTAMP>,<CONSUMPTION kWh>`. However, because this recording was done manually, the intervals between each record are arbitrary, making hour-by-hour statistical analysis difficult.
 - This program served to fix that, linearly interpolating between arbitrary intervals to estimate the power consumption exactly at the top of the hour.
 - This data could then be used to determine things like "50% of this circuit's consumption happened between 6pm and 8pm"

# Installation
 1. Clone this repo
 2. Execute `InterpolateElectric.sh`. No parameters required, everything is hard-coded. See the section on Usage for more details.

# Usage
 1. Provide a file named `data.csv` in the same directory as `InterpolateElectric.sh`.
 2. Populate information in `data.csv`, with each row being in the format `<UNIX TIMESTAMP>,<CONSUMPTION kWh>`; where the timestamp is an integer and the consumption is a float.
 3. Run `InterpolateElectic.sh`.
 4. Output will be written to `interpolate.csv` in the same directory as `InterpolateElectric.sh`. Output will be in the format `<TIMESTAMP>,<CONSUMPTION>,<INSTANTANEOUS CHANGE>,<HOUR>,<DATE>`; in the formats int, float, float, int [0:23], YYYY-MM-DD respectively.

# Sample Data
 `data.csv` and `interpolate.csv` contain sample data from my real-world usage patterns.

# History
 This project was originally written by Brendan Rood on or about 2024-10-31.