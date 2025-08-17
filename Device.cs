// This file contains C# classes representing the data structures used in the HomeSync Flutter application.
// This can be used for backend services or other applications interacting with the same Firebase database.

using System;
using System.Collections.Generic;

/// <summary>
/// Represents a smart home device.
/// </summary>
public class Device
{
    /// <summary>
    /// The name of the appliance (e.g., "Air-con", "Light 3").
    /// Corresponds to 'applianceName' in the Flutter app.
    /// </summary>
    public string ApplianceName { get; set; }

    /// <summary>
    /// The room where the device is located (e.g., "Bedroom", "Kitchen Area").
    /// Corresponds to 'roomName' in the Flutter app.
    /// </summary>
    public string RoomName { get; set; }

    /// <summary>
    /// The type of the device (e.g., "Socket 2", "Light").
    /// Corresponds to 'deviceType' in the Flutter app.
    /// </summary>
    public string DeviceType { get; set; }

    /// <summary>
    /// The relay associated with the device (e.g., "relay4", "relay6").
    /// This is used to control the physical state of the device.
    /// Corresponds to 'relay' in the Flutter app and the relay nodes in Firebase.
    /// </summary>
    public string Relay { get; set; }

    /// <summary>
    /// The code point of the MaterialIcons icon representing the device.
    /// Corresponds to 'icon' in the Flutter app.
    /// </summary>
    public int Icon { get; set; }

    /// <summary>
    /// The power consumption of the device in kilowatt-hours (kWh).
    /// Corresponds to 'kwh' in the Flutter app's add device screen.
    /// </summary>
    public double Kwh { get; set; }

    /// <summary>
    /// The scheduled start time for the device (e.g., "6:0", "18:30").
    /// Corresponds to 'startTime' in the Flutter app's add device screen.
    /// </summary>
    public string StartTime { get; set; }

    /// <summary>
    /// The scheduled end time for the device (e.g., "12:0", "23:0").
    /// Corresponds to 'endTime' in the Flutter app's add device screen.
    /// </summary>
    public string EndTime { get; set; }

    /// <summary>
    /// A list of days when the device is scheduled to be active (e.g., ["Mon", "Wed", "Fri"]).
    /// Corresponds to 'days' in the Flutter app's add device screen.
    /// </summary>
    public List<string> Days { get; set; }

    // Note: The 'state' of the relay (ON/OFF) is stored directly under the relay node in Firebase
    // (e.g., /relay1: { "state": 1 }). This is separate from the device configuration data.
}
