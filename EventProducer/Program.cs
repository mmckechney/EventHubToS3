using System;
using System.Collections.Generic;
using System.Linq;
using Azure.Messaging.EventHubs.Producer;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
namespace EventProducer 
{
    public class Program
    {
        public static int messageCount = 100;
        private static CancellationToken cancellationToken = new CancellationToken();
        public static async Task<int> Main(string[] args)
        {
            int tmp;
            if(args.Length == 1 && int.TryParse(args[0],out tmp))
            {
                messageCount = tmp;
            }

            var host = CreateHostBuilder(args);
            await host.RunConsoleAsync(Program.cancellationToken);
            return Environment.ExitCode;

        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .ConfigureServices((hostContext, services) =>
                {
                    services.AddHostedService<Worker>();
                });

    }
}