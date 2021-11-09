using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Producer;
using EventProducer;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;


namespace EventProducer
{
    internal class Worker : IHostedService
    {
        private readonly IHostApplicationLifetime applicationLifetime;
        private readonly ILogger<Worker> logger;
        private readonly IConfiguration config;
        static EventHubProducerClient producerClient;
        public Worker(ILogger<Worker> logger, IConfiguration config, IHostApplicationLifetime applicationLifetime)
        {
            this.logger = logger;
            this.config = config;
            this.applicationLifetime = applicationLifetime;
        }

        public async Task StartAsync(CancellationToken cancellationToken)
        {
            int numOfEvents = Program.messageCount;
            int batchSize = 500;
            int eventsSent = 0;
            int batchItemCounter = 0;
            try{
                // Create a producer client that you can use to send events to an event hub
                producerClient = new EventHubProducerClient(config["EventHubConnectionString"], config["EventHubName"]);

                // Create a batch of events 
                using EventDataBatch eventBatch = await producerClient.CreateBatchAsync();
                while(eventsSent < numOfEvents)
                {
                    while(batchItemCounter < batchSize)
                    {
                        if (!eventBatch.TryAdd(new EventData(Encoding.UTF8.GetBytes($"Event {eventsSent}"))))
                        {
                            // if it is too large for the batch
                            throw new Exception($"Event {batchSize} is too large for the batch and cannot be sent.");
                        }
                        eventsSent++;
                        batchItemCounter++;
                    }
                
                    try
                    {
                        // Use the producer client to send the batch of events to the event hub
                        await producerClient.SendAsync(eventBatch);
                        logger.LogInformation($"A batch of {batchItemCounter} events has been published. Total events so far: {eventsSent}");
                    }
                    catch(Exception exe)
                    {
                        logger.LogError(exe.Message);
                    }
                    batchItemCounter = 0;

                    if(cancellationToken.IsCancellationRequested)
                    {
                        return;
                    }
                }
            }
            finally
            {
                await producerClient.DisposeAsync();
            }

            return;
        }

        public Task StopAsync(CancellationToken cancellationToken)
        {
            return Task.CompletedTask;
        }

       
    }
}
