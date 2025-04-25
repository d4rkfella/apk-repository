#!/bin/bash

# Set directories
INSTALL_DIR="/opt/cuda"
DEB_DIR="/var/cuda-repo-ubuntu2404-12-8-local"  # Adjust to the correct path for your .deb files
TMP_DIR="/tmp/cuda-temp"

# Create installation directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$TMP_DIR"

# List of required CUDA package patterns
CUDA_PACKAGE_PATTERNS=(
    "cuda-nvcc"
    "cuda-compiler"
    "cuda-cudart-dev"
    "cuda-nvrtc-dev"
    "cuda-driver-dev"
    "libnvcuvid"
    "libnvidia-compute"
    "libnvidia-decode"
    "libnvidia-encode"
    "cuda-nvptxcompiler"
    "cuda-nvrtc"
    "cuda-cccl"
    "cuda-nvvm"
    "cuda-nvdisasm"
    "cuda-nvtx"
)

# Find all the .deb files in the CUDA repository folder
DEB_FILES=$(find "$DEB_DIR" -name "*.deb")

# Extract the required .deb packages dynamically
for PACKAGE_PATTERN in "${CUDA_PACKAGE_PATTERNS[@]}"; do
    # Filter and select .deb packages that match the pattern
    PACKAGE=$(echo "$DEB_FILES" | grep "$PACKAGE_PATTERN" | head -n 1)
    
    # Check if the package was found
    if [ -n "$PACKAGE" ]; then
        echo "Extracting $PACKAGE..."
        dpkg-deb -x "$PACKAGE" "$TMP_DIR"
        
        # Debug: List contents of the extraction
        echo "Listing extracted files from $PACKAGE:"
        ls -l "$TMP_DIR"
        
    else
        echo "Warning: No package found matching the pattern: $PACKAGE_PATTERN"
    fi
done

# Debug: Verify extracted files
echo "Checking extracted files in temp directory:"
ls -R "$TMP_DIR"

# Dynamically detect the CUDA directory (without hardcoding the version)
CUDA_DIR=$(find /tmp/cuda-temp/usr/local/ -maxdepth 1 -type d -name "cuda*" | head -n 1)

# Check if the CUDA directory exists
if [ ! -d "$CUDA_DIR" ]; then
    echo "Error: CUDA directory not found in extracted files. Aborting."
    exit 1
fi

# Extract the CUDA version from the directory (e.g., cuda-12.8)
CUDA_VERSION=$(basename "$CUDA_DIR")

echo "Detected CUDA version: $CUDA_VERSION"

# Copy extracted files to /opt/cuda
echo "Copying extracted files from $CUDA_DIR to $INSTALL_DIR..."
cp -r "$CUDA_DIR"/* "$INSTALL_DIR" 2>/dev/null

# Check if the copy was successful
if [ $? -ne 0 ]; then
    echo "Warning: Failed to copy files to $INSTALL_DIR."
else
    echo "Files successfully copied to $INSTALL_DIR."
fi

# Set environment variables (only for the current session)
echo "Setting up environment variables..."
export PATH="$INSTALL_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$INSTALL_DIR/lib64:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="$INSTALL_DIR/lib64/pkgconfig:$PKG_CONFIG_PATH"

# Create symlinks for CUDA binaries
echo "Creating symlinks for CUDA binaries..."
ln -sf "$INSTALL_DIR/bin/nvcc" /usr/local/bin/nvcc
ln -sf "$INSTALL_DIR/bin/cuda" /usr/local/bin/cuda

# Clean up temporary directory
echo "Cleaning up temporary directory..."
rm -rf "$TMP_DIR"

echo "CUDA installation is complete. The environment variables have been set for the current session."
echo "You can now compile FFmpeg with CUDA support."
