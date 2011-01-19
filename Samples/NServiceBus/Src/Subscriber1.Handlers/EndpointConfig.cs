using NServiceBus;
using NServiceBus.Config;
using NServiceBus.Config.ConfigurationSource;

namespace Subscriber1
{
    class EndpointConfig : IConfigureThisEndpoint, AsA_Server {}
}