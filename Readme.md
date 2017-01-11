#IoT Hub Workshop

At this workshop, we will establish guidance for building secure and scalable, device-centric solutions, conducting analysis and integrating into existing systems.  You will develop an IoT solution that collects data from a simulated device via an Azure IoT Hub gateway ingestion service, enables real-time processing through Azure Stream Analytics and explore options for integrating with back systems.  At the end of the workshop, you will walk away with a clear understanding of the key components to an Azure IoT solution that can help you facilitate valuable insights by harnessing the power of your untapped data.

The workshop is designed to introduce you to the many different components of an Azure IoT solution.  By the end you will have worked with all the major components and seen how they all fit together.  You could take the solution at the end of the workshop and build upon it for you specific scenario or you can look at one of the pre-built solutions that [Azure IoT Suite](https://www.azureiotsuite.com/) offers even more functionality.  This workshop will help you prepare for customize the Azure IoT Suite solutions.

The workshop is broken down into several steps:

1. Create IoT Hub in Azure
2. Create Simulated device
3. Create Azure Stream Analytics
4. Add Cold Path
5. Add Hot Path
6. Add PowerBi Real-time Reporting

## Before you begin
The Pre-requisites for the workshop are:

- Azure Subscription (Can sign up for free at [Azure SignUp](https://azure.microsoft.com/en-us/free/?b=17.01) or [Visual Studio Dev Essentials](https://www.visualstudio.com/dev-essentials/))
- Node.js 
- [Download IoT hub Explorer for Node.js](https://github.com/Azure/azure-iot-sdks/blob/master/doc/manage_iot_hub.md#iothub-explorer) 
- [Azure Storage Explorer](http://storageexplorer.com/) (optional)
- [Download ServiceBus Explorer](https://github.com/paolosalvatori/ServiceBusExplorer/releases) (optional)

## Create an IoT Hub in Azure
Log into your portal at http://portal.azure.com and create a new IoT Hub by clicking on ```Plus sign->Internet Of Things->Iot Hub```:

![new iot hub in portal](https://github.com/jsturtevant/iot-workshop/blob/master/images/iot-new-iot-hub-portal.png)

Next fill in the information on the IoT Hub Create Blade.  For the workshop select the ```Pricing and scale tier``` of free.  Create a new resource group called ```iot-workshop``` which we will place all our Azure resources in for this workshop and select a location near you.  Click ```Create``` and in a few minutes you will have your IoT Configured.

![create new iot hub](https://github.com/jsturtevant/iot-workshop/blob/master/images/iot-new-iot-hub-create.png)

## Create Simulated device
In this section we will [register a device in Azure IoT hub](#register-device) and then create a simulated device using the Node.Js (there are [c# samples here]().

### Register Device
Azure IoT hub has management API that can use to register devices and can be customized for your scenario.  In the case of the workshop will will be using a prebuilt tool called [IoT Hub Explorer](https://github.com/Azure/azure-iot-sdks/blob/master/doc/manage_iot_hub.md#iothub-explorer) that leverages the Management API's to register out simulated device.  The tool is [open source](https://github.com/Azure/iothub-explorer) so you can use it as an example if you need to develop more customized solution.  

Get your Azure IoT Connection String from the portal ```All Resources->Select your IoT Hub->Shared Access policies```.  Here for the IoT Hub Explorer we will choose the connection string for the ```iothubowner``` to have full control but when working with other connections you should select the least  policy needed.

![get azure IoT Hub connection string](https://github.com/jsturtevant/iot-workshop/blob/master/images/iot-new-iot-hub-connectionstring.png)

Once you have the tool installed open a command prompt and login to your IoT Hub:

```
iothub-explorer login <your-iothub-connection-string>
```

Next you can register your device using:

```
iothub-explorer create workshopdevice --connection-string
```

You can now see that device in the azure portal:

![see the device created in portal](C:\Projects\workshops\iot-quickstart\images\iot-new-iot-hub-device-created.png)

### Create Simulated Node.Js 
Next create a file called ```simulateddevice.js``` in your project folder and add the following to it:

```javascript
'use strict';

var clientFromConnectionString = require('azure-iot-device-amqp').clientFromConnectionString;
var Message = require('azure-iot-device').Message;

var connectionString = 'HostName=<hubname>.azure-devices.net;DeviceId=<deviceId>;SharedAccessKey=<yourkey>';

var client = clientFromConnectionString(connectionString);

function printResultFor(op) {
  return function printResult(err, res) {
    if (err) console.log(op + ' error: ' + err.toString());
    if (res) console.log(op + ' status: ' + res.constructor.name);
  };
}

var connectCallback = function (err) {
  if (err) {
    console.log('Could not connect: ' + err);
  } else {
    console.log('Client connected');

    // send random temp message every second
    setInterval(function(){
        var temp = 70 + (Math.random() * 20);
        var data = JSON.stringify({ deviceId: 'simulatedDevice', temp: temp });
        
        var message = new Message(data);
        console.log("Sending message: " + message.getData());
        client.sendEvent(message, printResultFor('send'));
    }, 1000);


    // set up Device listening for C2D
    client.on('message', function (msg) {
      console.log('Id: ' + msg.messageId + ' Body: ' + msg.data);
      client.complete(msg, printResultFor('completed'));

    });

    // handle errors
    client.on('error', function (err) {
      console.error(err.message);
    });

    // handle disconnect
    client.on('disconnect', function () {
      clearInterval(sendInterval);
      client.removeAllListeners();
      client.open(connectCallback);
    });
  }
};

//start client
client.open(connectCallback);
```

Next run ```npm init -y``` to create a ```package.json``` file. Open the file and add the following dependencies:

```
 "dependencies": {
    "azure-iot-device": "^1.0.15",
    "azure-iot-device-amqp": "^1.0.15"
  }
```

Install all the dependencies by running ```npm install```.

Get your Device Connection string either from the command line when you created the device with the IoT Hub Explorer or in the portal at:

![device connection string in portal](https://github.com/jsturtevant/iot-workshop/blob/master/images/iot-new-iot-hub-device-connectionstring.png)

Update the connection string in the ```simulatedDevice.js``` file.

Finally run your simulated device:

```bash
node simulatedDevice.js
# should see outputlike
Client connected
Sending message: {"deviceId":"simulatedDevice","temp":75.70230183395358}
send status: MessageEnqueued
Sending message: {"deviceId":"simulatedDevice","temp":76.50387904219407}
send status: MessageEnqueued
Sending message: {"deviceId":"simulatedDevice","temp":86.89145157479787}
send status: MessageEnqueued
Sending message: {"deviceId":"simulatedDevice","temp":76.26535003653802}
send status: MessageEnqueued
```

## Create Azure Stream Analytics
After created the simulated device we now ready to integrate the data into our back processing.  In a real scenario the data will becoming ingested into Azure IoT Hub at a large rate.  If you have 1000 devices in the field sending 1 message a second you would have 60,000 messages a minute being ingested into Azure IoT hub.  It is not uncommon to have many more devices.  Azure IoT Hub is designed to manage high volume through the use of partitions and Scale Units.

In many IoT solutions it is common to have a Hot and Cold path.  In the cold path you would dump the raw or aggregated data into storage for later analysis or processing.  The Hot path is typically used for alerts of critical parts of the system.  For instance in the workshop if the temperature is over 80 degrees we want to send a notification to so we can act and potentially resolve any issues.  To process the data on this Hot Path we need a real-time high through put system.  This is where Azure Stream Analytics comes in to play.  

> You can also write your own processors for custom logic.  Check out [this sample](https://github.com/codefoster/simple-azure-iot-hub/tree/master/service).

To create a Azure Stream Analytics job open the Azure portal and click ```Plus sign->Internet Of Things->Stream Analytics job```.  Give the job a name and it to the same resource group and region as before.  Then click ```Create``` and shortly you will have a new job.

![create azure stream analytics job](https://github.com/jsturtevant/iot-workshop/blob/master/images/iot-new-azure-stream-analytics-job.png)

### Add IoT Hub Input
Adding the IoT Hub input is easy as Azure has a fast integration setup between Azure Stream Analytics and Azure IoT Hub.  Click ```All resources->your stream analytics job -> overview -> inputs -> Add```.  Fill in the information for the Input using the IoT Hub from this subscription, use the ```service``` shared access policy and click create.  Optionally you could create a new Consumer Group in IoT hub for this instance of Azure Stream Analytics and selected that in this input creation.  Learn more about [device messaging](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-messaging) and [consumer groups](https://docs.microsoft.com/en-us/azure/event-hubs/event-hubs-overview.)  

![create azure stream analytics iothub input](https://github.com/jsturtevant/iot-workshop/blob/master/images/iot-new-azure-stream-analytics-job-iot-input.png)

## Add Cold Path 
To store data for later processing we will create a storage account and dump all the telemetry data to blob storage.  Later we could add 
optional processing on that data for analytics with things like Azure Data Factory.

### Blob Storage output
Create an Azure Stream analytics Output with blob storage.  You could use your own storage if you already have an existing.  In the case of the workshop we will create our own:

![azure stream analytics blob storage cold path output](https://github.com/jsturtevant/iot-workshop/blob/master/images/iot-new-azure-stream-analytics-job-cold-output.png)

### Create query for cold path
Next we need to write our query to move all the data from IoT Hub to the blob storage. 

![cold path query](https://github.com/jsturtevant/iot-workshop/blob/master/images/iot-new-azure-stream-analytics-job-cold-output-query.png)

## Add Hot Path
On the hot path we will do something a bit more interesting with our query to only trigger an event if the temperature is over 80 degrees.

### Create Azure Queue 
To store events we will you an Azure Queue. Depending on the scenario you can either use a Queue or EventHub.  

![azure stream analytics queue hot path output](https://github.com/jsturtevant/iot-workshop/blob/master/images/iot-new-azure-stream-analytics-job-hot-output.png)

### Create query for Hot Path
Next we need to write our query to trigger an alert for any temperature over 80 degrees.

![hot path query](https://github.com/jsturtevant/iot-workshop/blob/master/images/iot-new-azure-stream-analytics-job-hot-output-query.png)

### Start Azure Stream Analytics
Now that we have all of our inputs, outputs, and queries created we can start the job.  Note that you can not edit the job while it is running.  It takes a few moments to start the job.

![start job](https://github.com/jsturtevant/iot-workshop/blob/master/images/iot-new-azure-stream-analytics-job-start.png)

### Review Cold path data
You can use the [Azure Storage Explorer](http://storageexplorer.com/) to view the data from the cold path.

### Create an Azure Function to Process Hot Path
There are many ways to process the data for the Hot Path.  One of the easiest with with Azure Functions as they have built in integrations, scale well, and you only pay for what you use.

Create a new Azure Function App:

![azure function app](https://github.com/jsturtevant/iot-workshop/blob/master/images/iot-function-app.png)

Create a new function for Service Bus Queue.  You will need to get your Service Bus Queue connection string (todo).

![azure function app function for service ](https://github.com/jsturtevant/iot-workshop/blob/master/images/iot-function-app-create-function.png)
