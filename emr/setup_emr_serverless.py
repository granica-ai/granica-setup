import argparse
import time
import sys

import boto3


def wait_for_state_transition(
    emr_serverless, application_id, current_state, timeout=600
):
    """Wait for application to transition out of current state"""
    start_time = time.time()
    while time.time() - start_time < timeout:
        response = emr_serverless.get_application(applicationId=application_id)
        status = response["application"]["state"]

        if status != current_state:
            print(f"⏳ Application transitioned from {current_state} to {status}")
            return status

        print(f"⏳ Application still in {current_state} state...")
        time.sleep(20)

    raise TimeoutError(
        f"Timeout waiting for application to transition from {current_state}"
    )


def start_spark_application(application_id, region):
    """
    Starts an EMR Serverless Spark application.
    Handles all possible application states.
    """
    try:
        emr_serverless = boto3.client("emr-serverless", region_name=region)

        # Get current application state
        response = emr_serverless.get_application(applicationId=application_id)
        status = response["application"]["state"]
        print(f"Current application status: {status}")

        # Handle each possible state
        while True:
            if status == "STARTED":
                print(f"✅ Application {application_id} is running.")
                return True

            elif status in ["STOPPED", "CREATED"]:
                print(f"🚀 Starting application {application_id}...")
                emr_serverless.start_application(applicationId=application_id)
                status = "STARTING"
                continue

            elif status == "CREATING":
                print("⏳ Application is being created...")
                status = wait_for_state_transition(
                    emr_serverless, application_id, status
                )
                continue

            elif status == "STARTING":
                print("⏳ Waiting for application to start...")
                try:
                    status = wait_for_state_transition(
                        emr_serverless, application_id, status
                    )
                    continue
                except TimeoutError:
                    print("⚠️ Application start timed out after 10 minutes.")
                    return False

            elif status == "STOPPING":
                print("⏳ Waiting for application to stop before restarting...")
                status = wait_for_state_transition(
                    emr_serverless, application_id, status
                )
                continue

            elif status in ["TERMINATING", "TERMINATED"]:
                print(f"❌ Cannot start application: {status}")
                return False

            else:
                print(f"⚠️ Unexpected application status: {status}")
                return False

    except boto3.exceptions.Boto3Error as boto_err:
        print(f"❌ AWS SDK Error: {boto_err}")
        return False
    except TimeoutError as te:
        print(f"❌ Timeout Error: {str(te)}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {str(e)}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Start EMR Serverless Application")
    parser.add_argument(
        "--application-id", required=True, help="EMR Serverless Application ID"
    )
    parser.add_argument(
        "--region", default="us-east-2", help="AWS region (default: us-east-2)"
    )
    parser.add_argument(
        "--timeout", type=int, default=600, help="Timeout in seconds (default: 600)"
    )

    args = parser.parse_args()

    if start_spark_application(args.application_id, args.region):
        print("\n✅ EMR Serverless application is now running!")
    else:
        print("\n❌ Failed to start application.")
        sys.exit(1)


if __name__ == "__main__":
    main()
