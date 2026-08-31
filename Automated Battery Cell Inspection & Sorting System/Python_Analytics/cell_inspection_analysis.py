import random
import csv
import matplotlib.pyplot as plt

VOLTAGE_MIN = 3.5
VOLTAGE_MAX = 4.2

HEIGHT_MIN = 79.5
HEIGHT_MAX = 80.5

NUM_CELLS = 100

pass_count = 0
reject_count = 0
voltage_rejects = 0
height_rejects = 0
both_rejects = 0
cell_data = []

for cell_id in range(1, NUM_CELLS + 1):
    cell_voltage = round(random.uniform(3.3, 4.4), 2)
    cell_height = round(random.uniform(79.0, 81.0), 2)

    voltage_ok = VOLTAGE_MIN <= cell_voltage <= VOLTAGE_MAX
    height_ok = HEIGHT_MIN <= cell_height <= HEIGHT_MAX

    if voltage_ok and height_ok:
        result = "PASS"
        reject_reason = "None"
        pass_count += 1
    else:
        result = "REJECT"
        reject_count += 1

        if not voltage_ok and not height_ok:
            reject_reason = "Voltage and Height"
            both_rejects += 1
        elif not voltage_ok:
            reject_reason = "Voltage"
            voltage_rejects += 1
        else:
            reject_reason = "Height"
            height_rejects += 1

    print(cell_id, cell_voltage, cell_height, result)
    cell_data.append([cell_id, cell_voltage, cell_height, result, reject_reason])

total_count = pass_count + reject_count
pass_rate = (pass_count / total_count) * 100
reject_rate = (reject_count / total_count) * 100

print("\n--- BATCH SUMMARY ---")
print("Total Cells:", total_count)
print("Passed:", pass_count)
print("Rejected:", reject_count)
print("Pass Rate:", round(pass_rate, 2), "%")
print("Reject Rate:", round(reject_rate, 2), "%")

print("\n--- REJECT SUMMARY ---")
print("Voltage Rejects:", voltage_rejects)
print("Height Rejects:", height_rejects)
print("Both Rejects:", both_rejects)

with open("cell_inspection_data.csv", "w", newline="") as file:
    writer = csv.writer(file)

    writer.writerow(["Cell ID", "Voltage (V)", "Height (mm)", "Result", "Reject Reason"])
    writer.writerows(cell_data)

print("\nInspection data saved to cell_inspection_data.csv")

labels = ["Pass", "Reject"]
counts = [pass_count, reject_count]

plt.bar(labels, counts)
plt.title("Battery Cell Inspection Results")
plt.ylabel("Number of Cells")
plt.savefig("inspection_results.png")
plt.show()

reject_labels = ["Voltage", "Height", "Voltage & Height"]
reject_counts = [voltage_rejects, height_rejects, both_rejects]

plt.bar(reject_labels, reject_counts)
plt.title("Battery Cell Reject Reasons")
plt.ylabel("Number of Cells")
plt.savefig("reject_reasons.png")
plt.show()