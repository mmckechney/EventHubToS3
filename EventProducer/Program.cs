﻿using System;
using System.Collections.Generic;
using System.Linq;
using Azure.Messaging.EventHubs.Producer;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace EventProducer 
{
    public class Program
    {
        public static int messageCount = 100;
        public static int batchSize = 100;
        private static CancellationToken cancellationToken = new CancellationToken();
        public static async Task<int> Main(string[] args)
        {

            var host = CreateHostBuilder(args).UseConsoleLifetime();
            await host.RunConsoleAsync(Program.cancellationToken);
            return Environment.ExitCode;

        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .ConfigureServices((hostContext, services) =>
                {
                    services.AddHostedService<Worker>();
                    services.AddSingleton<Worker.StartArgs>(new Worker.StartArgs(args));
                    services.AddSingleton<CommandSetUp>();
                    
                })
                 .ConfigureLogging((hostContext, logging) =>
                 {
                     logging.AddConsole();
                     logging.SetMinimumLevel(Microsoft.Extensions.Logging.LogLevel.Information);
                     logging.AddFilter("Microsoft", LogLevel.Warning);
                     logging.AddFilter("System", LogLevel.Warning);
                 });

    }
}