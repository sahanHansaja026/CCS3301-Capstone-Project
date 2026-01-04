import os

# List of folder paths (add your 5 paths here)
folder_paths = [
    r"C:\Users\DESHANI\Downloads\archive\Gracula ptilogenys",
    r"C:\Users\DESHANI\Downloads\archive\testing",
]

base_name = input("Enter the base name: ")

for folder_path in folder_paths:
    print(f"\nProcessing folder: {folder_path}")

    # List only files (ignore subfolders)
    files = sorted(
        f for f in os.listdir(folder_path)
        if os.path.isfile(os.path.join(folder_path, f))
    )

    for index, file in enumerate(files, start=1):
        extension = os.path.splitext(file)[1]
        new_name = f"{base_name}_{index:02d}{extension}"

        old_path = os.path.join(folder_path, file)
        new_path = os.path.join(folder_path, new_name)

        os.rename(old_path, new_path)

    print("✔ Renaming completed for this folder")

print("\n✅ All folders processed successfully!")
