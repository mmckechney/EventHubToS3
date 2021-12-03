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
using System.Reflection;
using System.CommandLine;
using System.Drawing;
using System.Diagnostics.Eventing.Reader;

namespace EventProducer
{
    internal class Worker : IHostedService
    {
        private readonly IHostApplicationLifetime applicationLifetime;
        private readonly ILogger<Worker> logger;
        private readonly IConfiguration config;
        private static EventHubProducerClient producerClient;
        private string[] startArgs;
        private CommandSetUp cmdSetup;
        CancellationToken cancellationToken;

        public Worker(ILogger<Worker> logger, CommandSetUp cmdSetup, StartArgs args, IConfiguration config, IHostApplicationLifetime applicationLifetime)
        {
            this.logger = logger;
            this.config = config;
            this.applicationLifetime = applicationLifetime;
            this.startArgs = args.Args;
            this.cmdSetup = cmdSetup;
        }

        public async Task StartAsync(CancellationToken cancellationToken)
        {
            this.cancellationToken = cancellationToken;
            producerClient = new EventHubProducerClient(config["EventHubConnectionString"], config["EventHubName"]);
            string[] args = startArgs;
            var rootCommand = cmdSetup.ConfigureRootCommand(this);
            string[] exitKeywords = new string[] { "exit", "quit", "q" };
            int val = await rootCommand.InvokeAsync(args);
            logger.LogInformation("Complete!");
            applicationLifetime.StopApplication();

        }

        private byte[] CreateSampleEvent(int size)
        {
            Random random = new Random();
            byte[] data = new byte[size];
            for(int i=0;i< size;i++)
            {
                random.NextBytes(data);
            }
            return data;
        }
        internal async Task<int> SendEvents(int count, int messageSize)
        {
            var sampleMessageBytes = CreateSampleEvent(messageSize);
            int batchItemCounter = 0;
            using EventDataBatch eventBatch = await producerClient.CreateBatchAsync();
            while (true)
            {
                if (!eventBatch.TryAdd(new EventData(sampleMessageBytes)))
                {
                    logger.LogInformation($"Setting batch to optimum size of {batchItemCounter} messages");
                    return await SendEvents(count, messageSize, batchItemCounter, sampleMessageBytes);
                }
                batchItemCounter++;
            }
        }
        private  async Task<int> SendEvents(int count, int messageSize, int batchSize, byte[] sampleMessageBytes)
        {
            int success = 0;

            int numberOfFullBatches = count / batchSize;
            int lastBatchSize = count % batchSize;
            int eventsSentCounter = 0;
            try
            {
                for (int b = 0; b < numberOfFullBatches; b++)
                {
                    await SendSingleBatch(batchSize, sampleMessageBytes, eventsSentCounter);
                    eventsSentCounter = eventsSentCounter + batchSize;
                    if (cancellationToken.IsCancellationRequested)
                    {
                        return 1;
                    }
                }
                await SendSingleBatch(lastBatchSize, sampleMessageBytes, eventsSentCounter);

            }
            finally
            {
                await producerClient.DisposeAsync();
            }

            return success;
        }
        public async Task SendSingleBatch(int messageCount, byte[] sampleMessageBytes, int eventsSendCounter)
        {

            EventDataBatch eventBatch = await producerClient.CreateBatchAsync();

            for (int i = 0; i < messageCount; i++)
            {
                eventBatch.TryAdd(new EventData(sampleMessageBytes));
            }
            

            logger.LogInformation($"A batch of { messageCount} events has been has been published. Total events so far: {eventsSendCounter + messageCount}");
            await producerClient.SendAsync(eventBatch);

        }
        public Task StopAsync(CancellationToken cancellationToken)
        {
            return Task.CompletedTask;
        }

        internal class StartArgs
        {
            public string[] Args { get; set; }
            public StartArgs(string[] args)
            {
                this.Args = args;
            }
        }

    }
}
