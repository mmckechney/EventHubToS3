using Microsoft.Extensions.Logging;
using System.CommandLine;
using System.CommandLine.Invocation;
namespace EventProducer
{
    internal class CommandSetUp
    {
        ILogger log;
        public CommandSetUp(ILogger<CommandSetUp> log)
        {
            this.log = log;
        }

        public RootCommand ConfigureRootCommand(Worker worker)
        {
            var messageCount = new Option<int>(new string[] { "-c", "--count" }, $"Number of Test Events to send to EventHub.") { IsRequired = true };
            var eventSize = new Option<int>(new string[] { "-s", "--message-size" }, () => 1000, "Size of test events (in bytes). Use this to reflect the size of your actual messages") { IsRequired = false };

            RootCommand rootCommand = new RootCommand(description: $"Console app to send test events to an Azure Event Hub{Environment.NewLine}(Edit the appsettings.json to add your EventHubConnectionString and EventHubName)");
            rootCommand.Handler = CommandHandler.Create<int, int>(worker.SendEvents);
            rootCommand.Add(messageCount);
            rootCommand.Add(eventSize);

            return rootCommand;
        }
    }
}
