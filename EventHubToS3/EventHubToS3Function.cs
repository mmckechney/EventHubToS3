using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using Amazon.S3;
using Amazon.S3.Model;
using Amazon.S3.Transfer;
using Azure.Core;
using Azure.Messaging.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using static Amazon.Internal.RegionEndpointProviderV2;

namespace EventHubToS3
{
    public static class EventHubToS3Function
    {
        [FunctionName("EventHubToS3Function")]
        public static async Task Run([EventHubTrigger("%EventHubName%", Connection = "EventHubConnectionString")] EventData[] events, ILogger log)
        {
            var exceptions = new List<Exception>();

            foreach (EventData eventData in events)
            {
                try
                {
                    string messageBody = Encoding.UTF8.GetString(eventData.Body.ToArray());

                    // Replace these two lines with your processing logic.
                    log.LogInformation($"C# Event Hub trigger function processed a message: {messageBody}");
                    await Task.Yield();

                    var s3Secret = Environment.GetEnvironmentVariable("S3Secret");
                    var s3AccessKey = Environment.GetEnvironmentVariable("S3AccessKey");
                    var s3BucketName = Environment.GetEnvironmentVariable("S3BucketName");
                    var s3RequestKey = "SampleMessage-"+ Guid.NewGuid().ToString().Replace("-","").Substring(0,10); // if  you are trying to upload file then give any name for that file.

                    // Create AmazonS3Client using secrets
                    var awsClient = new AmazonS3Client(s3AccessKey, s3Secret, Amazon.RegionEndpoint.USEast1);
             
                    var request = new PutObjectRequest()
                    {
                        Key = s3RequestKey,
                        BucketName = s3BucketName,
                        ContentBody = messageBody
                    };
                    PutObjectResponse responseFromAWS = await awsClient.PutObjectAsync(request);

                    // check status of upload operation 
                    if (responseFromAWS.HttpStatusCode.Equals(HttpStatusCode.OK))
                    {
                        log.LogInformation("Event message uploaded successfully");
                    }
                    else
                    {
                        log.LogError("Failed to upload message on S3 Bucket");

                    }
            }
                catch (Exception e)
                {
                    // We need to keep processing the rest of the batch - capture this exception and continue.
                    // Also, consider capturing details of the message that failed processing so it can be processed again later.
                    exceptions.Add(e);
                }
            }

            // Once processing of the batch is complete, if any messages in the batch failed processing throw an exception so that there is a record of the failure.

            if (exceptions.Count > 1)
                throw new AggregateException(exceptions);

            if (exceptions.Count == 1)
                throw exceptions.Single();
        }
    }
}
