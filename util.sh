#!/bin/bash

# Function to encrypt a file and output the result
encrypt_and_output() {
  local file_path=$1
  local passphrase=$2
  gpg --armor --symmetric --batch --pinentry-mode loopback --passphrase "$passphrase" --output - "$file_path"
}

# Function to output download information for the uploaded file
output_uploaded_file_download_metadata() {
    local download_link=$1
    local file=$2
    local service_name=$3

    # Check if the download link is empty (e.g., due to a timeout)
    if [ -z "$download_link" ]; then
        echo "Failed to upload the file to $service_name."
        return 1 # Indicate failure
    else
        echo "Upload done."
        echo
    fi

    # Prepare the download and decrypt commands
    local encrypted_filename="encrypted_$file"
    local decrypted_filename="decrypted_$file"


    echo
    echo "Please use the following command \"$VALIDATOR_TRANSACTION_SIGNERS_EMAILS\" to download, decrypt, and save the file:"
    echo
    echo "curl -o /tmp/${encrypted_filename} https://file.io/LQcjiJ8CHdSO && gpg --decrypt --batch --pinentry-mode loopback --passphrase $passphrase -o /tmp/$decrypted_filename /tmp/${encrypted_filename}"
    echo
    echo

    return 0 # Success
}

# Function to attempt uploading the encrypted data to various services
upload_encrypted_data() {
    local encrypted_data="$1"
    local file="$2"
    local filePath="$4"
    local passphrase="$5"

    # Initialize upload success flag
    local uploadIsDone=0

    # Define an array of services
    local services=(
        "catbox.moe|https://catbox.moe/user/api.php|-F \"reqtype=fileupload\" -F \"fileToUpload=@-\"|200"
        "file.io|https://file.io|-F \"file=@-\" -F \"expires=2d\"|200"
        "0x0.st|https://0x0.st|-F \"file=@-\"|200"
        "transfer.sh|https://transfer.sh/$file|--upload-file -|200"
        "gofile.io|https://store1.gofile.io/uploadFile|-F \"file=@-\"|200"
    )

    for service_info in "${services[@]}"; do
        if [ $uploadIsDone -eq 0 ]; then
            IFS='|' read -r service_name upload_url upload_params expected_status_code <<< "$service_info"

            echo "Attempting to upload encrypted file to $service_name..."

            # Create a temporary file to store the response body
            tmpfile=$(mktemp)

            # Execute the curl command
            status_code=$(echo "$encrypted_data" | eval "curl -s --connect-timeout $UPLOAD_TIMEOUT_IN_SECONDS $upload_params $upload_url -w \"%{http_code}\" -o \"$tmpfile\"")

            # Read the response body from the temporary file
            response_body=$(cat "$tmpfile")
            rm "$tmpfile"

            # Check if the status code is the expected one
            if [ "$status_code" -eq "$expected_status_code" ]; then
                # Parse the download link based on the service
                case "$service_name" in
                    "catbox.moe"|"0x0.st"|"transfer.sh")
                        download_link="$response_body"
                        ;;
                    "file.io")
                        # Extract the download link from the JSON response
                        download_link=$(echo "$response_body" | grep -o '"link":"[^"]*"' | cut -d'"' -f4)
                        ;;
                    "gofile.io")
                        # Extract the download link from the JSON response
                        download_link=$(echo "$response_body" | grep -o '"downloadPage":"[^"]*"' | cut -d'"' -f4)
                        ;;
                    *)
                        download_link="$response_body"
                        ;;
                esac

                echo "Upload successful, download link: $download_link"

                if output_uploaded_file_download_metadata "$download_link" "$file" "$service_name"; then
                    uploadIsDone=1
                fi
            else
                echo "Upload failed with status code: $status_code"
            fi
        fi
    done

    if [ $uploadIsDone -eq 0 ]; then
        echo
        echo "Failed to upload encrypted file to one of the available services."
        echo "Please manually upload the file. It can be found at '$filePath'"
    fi
}

