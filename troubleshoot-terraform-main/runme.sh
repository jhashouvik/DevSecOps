#!/bin/sh

#---------------------------------------------#
# Author: Adam Wezva Technologies
# Call/Whatsapp: +91-9739110917
# www.wezvatech.in
#---------------------------------------------#

LAB_DIR="./lab"
BUCKET_NAME="wezvatech-interview-prep-bucket" # Must match your backend.tf
STATE_KEY="troubleshoot-lab/security-group.tfstate"

init_env() {
    echo "📦 Initializing Terraform with remote S3 backend..."
    cd "$LAB_DIR" || exit
    terraform init -input=false
    cd ..
}

print_header() {
    echo "==============================================="
    echo " 🎓 WEZVATECH TERRAFORM TROUBLESHOOTING STEPS"
    echo "==============================================="
}

case "$1" in
    1)
        echo -e "\n🔥 [SCENARIO 1] Simulating Interrupted Pipeline & Stuck S3 Native Lock..."
        init_env
        cd "$LAB_DIR" || exit

        echo "🚀 Launching terraform apply in the background..."
        terraform apply -auto-approve &
        TF_PID=$!

        echo "⏳ Allowing Resource 1 (sg_1) to finish creating and commit to state..."
        sleep 5

        echo "💥 CRASH! Force-killing the Terraform execution process (PID: $TF_PID) mid-flight..."
        kill -9 $TF_PID &>/dev/null
        cd ..

        echo -e "\n🛑 The pipeline process has been killed abruptly while holding the lock backend."
        echo -e "💥 NEXT LAB STEP: Run 'cd lab && terraform plan'"
        echo -e "💡 EXPECTED ERROR: You will now get an S3 Native Lock lease acquisition error because the process was killed before it could release its lock file metadata wrapper!"
        echo ""
        print_header
        echo "📝 INTERVIEW ANSWER MATRIX FOR SCENARIO 1 (Stuck S3 Native Locks):"
        echo "1. THE SITUATION: The runner died abruptly. Resource 1 exists, but the remote S3"
        echo "   lock lease was never cleanly dismantled."
        echo "2. STEP 1 [Verify Process Safety]: Ensure that the crashed pipeline instance or"
        echo "   background process is truly dead before touching anything."
        echo "3. STEP 2 [Extract Lock ID]: Run 'terraform plan', parse the terminal error string,"
        echo "   and copy the unique S3 native 'Lock ID'."
        echo "4. STEP 3 [Force Break Lock]: Clear the stuck state lock metadata entry out of the"
        echo "   S3 cluster path manually by executing: 'terraform force-unlock <LOCK_ID>'"
        echo "5. STEP 4 [Verify & Resume]: Run 'terraform plan' again. It will now bypass the lock,"
        echo "   recognize that sg_1 is safely built, and cleanly prompt to only deploy sg_2."
        echo "========================================================================="
        ;;
    2)
        echo -e "\n🔥 [SCENARIO 2] Simulating Accidental S3 State File Deletion..."
        echo "🗑️ Using AWS CLI to delete the remote state file directly from S3..."
        aws s3api delete-object --bucket "$BUCKET_NAME" --key "$STATE_KEY"

        echo -e "\n💥 DAMAGE DONE: The remote state file has been purged from your S3 bucket path."
        echo -e "💥 NEXT LAB STEP: Run 'cd lab && terraform plan' to see Terraform try to recreate everything."
        echo ""
        print_header
        echo "📝 INTERVIEW ANSWER MATRIX FOR SCENARIO 2:"
        echo "🚨 WARNING: DO NOT RUN 'terraform apply'! It will create duplicate resources or crash."
        echo ""
        echo "1. STEP 1 [Immediate Freeze]: Enforce a code freeze and stop all active CI/CD pipelines"
        echo "   targeting this AWS account environment immediately."
        echo "2. STEP 2 [S3 Rollback - Preferred]: If S3 Bucket Versioning is active, go to the AWS"
        echo "   Console, click 'Show Versions', locate the 'Delete Marker', and remove it to restore"
        echo "   the state file instantly."
        echo "3. STEP 3 [State Push - Alternative]: If versioning fails but you have a local copy or a"
        echo "   recent CI/CD workspace cache file ('terraform.tfstate'), push it to the remote backend"
        echo "   using: 'terraform state push backup.tfstate'"
        echo "4. STEP 4 [Manual Import - Last Resort]: If no backups exist, write empty shell definitions"
        echo "   in 'main.tf' and stitch the state back together element-by-element using:"
        echo "   'terraform import aws_security_group.sg_1 <live-sg-id-from-aws>'"
        echo "========================================================================="
        ;;

    3)
        echo -e "\n🔥 [SCENARIO 3] Simulating Production Configuration Drift..."
        echo "⚡ Fetching live Security Group to inject out-of-band configurations..."
        SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=wezva-prod-web-sg" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

        if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
            echo "❌ Error: Could not find 'wezva-prod-web-sg' in AWS."
            echo "💡 Fix: Run a successful 'terraform apply' inside the lab folder first to create it."
            exit 1
        fi

        echo "🚨 Direct user action: Manually opening Port 22 (SSH) on $SG_ID bypassing IaC..."
        aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 &>/dev/null

        echo -e "\n💥 DRIFT PROVOKED: Port 22 has been injected directly via AWS API/Console."
        echo -e "💥 NEXT LAB STEP: Run 'cd lab && terraform plan' to see how it flags the rogue port."
        echo ""
        print_header
        echo "📝 INTERVIEW ANSWER MATRIX FOR SCENARIO 3:"
        echo "1. STEP 1 [Understand the Refresh Phase]: Explain that whenever a plan runs, Terraform"
        echo "   makes read-only API calls to AWS to contrast actual cloud properties with the state map."
        echo "2. STEP 2 [Evaluate Drift Strategy]: Coordinate with the team to identify if the manual change"
        echo "   was a dangerous rogue modification or an emergency fix that needs to stay permanent."
        echo "3. STEP 3 [Action A - Enforce Compliance]: If the modification is unsafe, run 'terraform apply'."
        echo "   Terraform will cleanly strip out the unmapped port 22 configuration to match the code."
        echo "4. STEP 4 [Action B - Reconcile Code]: If the rule must stay permanent, manually document"
        echo "   the port 22 rule directly inside the 'main.tf' file so the configuration aligns again."
        echo "   ingress {"
        echo "       from_port   = 443"
        echo "       to_port     = 443"
        echo "       protocol    = \"tcp\""
        echo "       cidr_blocks = [\"0.0.0.0/0\"]"
        echo "   }"
        echo "========================================================================="
        ;;

    clean)
        echo "🧹 Cleaning up footprints..."
        cd "$LAB_DIR" && terraform destroy -auto-approve 2>/dev/null
        cd ..
        echo "✅ Cleanup complete."
        ;;
    -h | --h )
        clear
        echo "==================================================="
        echo "#         WEZVATECH - ADAM - 9739110917           #"
        echo "==================================================="
        echo "Syntax:  $0 <option>"
        echo "Syntax:  $0 [1|2|3|clean]"
        echo " Options:"
        echo "  1:  Interrupted Pipeline & Statelock"
        echo "  2:  Statefile Deletion"
        echo "  3:  Configuration Drift"
        echo "==================================================="
        exit 0 ;;
      * ) echo "Run the script with -h to get help"; exit 0;;
esac

