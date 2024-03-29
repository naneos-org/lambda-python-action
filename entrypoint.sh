#!/bin/bash
set -e

# Fix the unsafe repo error which was introduced by the CVE-2022-24765 git patches
git config --global --add safe.directory /github/workspace

############## Definitions part
deploy_lambda_dependencies () {

    echo "Installing dependencies..."
    mkdir -p python/lib/python3.8/site-packages > /dev/null 2>&1
    pip install -t ./python/lib/python3.8/site-packages -r "${INPUT_REQUIREMENTS_TXT}" > /dev/null 2>&1
    echo "OK"

    echo "Zipping dependencies..."
    zip -r python.zip ./python > /dev/null 2>&1
    rm -rf python > /dev/null 2>&1
    echo "OK"

    echo "Publishing dependencies layer..."
    response=$(aws lambda publish-layer-version --compatible-runtimes python3.8 --layer-name "${INPUT_LAMBDA_LAYER_ARN}" --zip-file fileb://python.zip)
    VERSION=$(echo $response | jq '.Version')
    rm python.zip > /dev/null 2>&1
    echo "OK"

    echo "Updating lambda layer version..."
    aws lambda update-function-configuration --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --layers "${INPUT_LAMBDA_LAYER_ARN}:${VERSION}" > /dev/null 2>&1
    echo "OK\n"
    echo "Depencencies was deployed successfully"
}

############## Git config
git remote set-url origin "https://${INPUT_TOKEN}@github.com/${GITHUB_REPOSITORY}"
CHANGED_FILES=()

############## Main part
echo "AWS configuration..."
aws configure set default.region "${INPUT_LAMBDA_REGION}" > /dev/null 2>&1
echo "OK"

echo "Deploying lambda main code..."
cd ${INPUT_SOURCES_DIR}
zip -r ../lambda.zip ./* -x \*.git\*
cd ..
aws lambda update-function-code --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --zip-file fileb://lambda.zip
echo "OK"

### Deploy dependencies if INPUT_LAMBDA_LAYER_ARN was defined in action call
[ ! -z "${INPUT_LAMBDA_LAYER_ARN}" ] && deploy_lambda_dependencies || echo "Dependencies wasn't deployed."

echo "${INPUT_LAMBDA_FUNCTION_NAME} function was deployed successfully."
