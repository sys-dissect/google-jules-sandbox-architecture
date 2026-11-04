/*
 * Intel ACPI Component Architecture
 * AML/ASL+ Disassembler version 20260930 (64-bit version)
 * Copyright (c) 2000 - 2026 Intel Corporation
 * 
 * Disassembling to symbolic ASL+ operators
 *
 * Disassembly of sys/firmware/acpi/tables/DSDT
 *
 * Original Table Header:
 *     Signature        "DSDT"
 *     Length           0x0000033A (826)
 *     Revision         0x02
 *     Checksum         0x6C
 *     OEM ID           "FIRECK"
 *     OEM Table ID     "FCVMDSDT"
 *     OEM Revision     0x00000000 (0)
 *     Compiler ID      "FCAT"
 *     Compiler Version 0x20240119 (539230489)
 */
DefinitionBlock ("", "DSDT", 2, "FIRECK", "FCVMDSDT", 0x00000000)
{
    Device (V000)
    {
        Name (_HID, "LNRO0005")  // _HID: Hardware ID
        Name (_UID, 0x00000000)  // _UID: Unique ID
        Name (_CCA, One)  // _CCA: Cache Coherency Attribute
        Name (_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
        {
            Memory32Fixed (ReadWrite,
                0xC0001000,         // Address Base
                0x00001000,         // Address Length
                )
            Interrupt (ResourceConsumer, Edge, ActiveHigh, Exclusive, ,, )
            {
                0x00000005,
            }
        })
    }

    Device (V001)
    {
        Name (_HID, "LNRO0005")  // _HID: Hardware ID
        Name (_UID, 0x00000001)  // _UID: Unique ID
        Name (_CCA, One)  // _CCA: Cache Coherency Attribute
        Name (_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
        {
            Memory32Fixed (ReadWrite,
                0xC0002000,         // Address Base
                0x00001000,         // Address Length
                )
            Interrupt (ResourceConsumer, Edge, ActiveHigh, Exclusive, ,, )
            {
                0x00000006,
            }
        })
    }

    Device (V002)
    {
        Name (_HID, "LNRO0005")  // _HID: Hardware ID
        Name (_UID, 0x00000002)  // _UID: Unique ID
        Name (_CCA, One)  // _CCA: Cache Coherency Attribute
        Name (_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
        {
            Memory32Fixed (ReadWrite,
                0xC0003000,         // Address Base
                0x00001000,         // Address Length
                )
            Interrupt (ResourceConsumer, Edge, ActiveHigh, Exclusive, ,, )
            {
                0x00000007,
            }
        })
    }

    Device (V003)
    {
        Name (_HID, "LNRO0005")  // _HID: Hardware ID
        Name (_UID, 0x00000003)  // _UID: Unique ID
        Name (_CCA, One)  // _CCA: Cache Coherency Attribute
        Name (_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
        {
            Memory32Fixed (ReadWrite,
                0xC0004000,         // Address Base
                0x00001000,         // Address Length
                )
            Interrupt (ResourceConsumer, Edge, ActiveHigh, Exclusive, ,, )
            {
                0x00000008,
            }
        })
    }

    Device (_SB.GED)
    {
        Name (_HID, "ACPI0013" /* Generic Event Device */)  // _HID: Hardware ID
        Name (_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
        {
            Interrupt (ResourceConsumer, Edge, ActiveHigh, Exclusive, ,, )
            {
                0x00000009,
            }
        })
        Method (_EVT, 1, Serialized)  // _EVT: Event
        {
            If ((Arg0 == 0x09))
            {
                Notify (\_SB.VGEN, 0x80) // Status Change
            }
        }
    }

    Device (_SB.VGEN)
    {
        Name (_HID, "FCVMGID")  // _HID: Hardware ID
        Name (_CID, "VM_Gen_Counter")  // _CID: Compatible ID
        Name (_DDN, "VM_Gen_Counter")  // _DDN: DOS Device Name
        Name (ADDR, Package (0x02)
        {
            0x000DFFF0, 
            0x00000000
        })
    }

    Device (_SB.COM1)
    {
        Name (_HID, EisaId ("PNP0501") /* 16550A-compatible COM Serial Port */)  // _HID: Hardware ID
        Name (_UID, 0x00)  // _UID: Unique ID
        Name (_DDN, "COM1")  // _DDN: DOS Device Name
        Name (_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
        {
            Interrupt (ResourceConsumer, Edge, ActiveHigh, Exclusive, ,, )
            {
                0x00000004,
            }
            IO (Decode16,
                0x03F8,             // Range Minimum
                0x03F8,             // Range Maximum
                0x01,               // Alignment
                0x08,               // Length
                )
        })
    }

    Device (_SB.COM2)
    {
        Name (_HID, EisaId ("PNP0501") /* 16550A-compatible COM Serial Port */)  // _HID: Hardware ID
        Name (_UID, 0x01)  // _UID: Unique ID
        Name (_DDN, "COM2")  // _DDN: DOS Device Name
        Name (_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
        {
            Interrupt (ResourceConsumer, Edge, ActiveHigh, Exclusive, ,, )
            {
                0x00000003,
            }
            IO (Decode16,
                0x02F8,             // Range Minimum
                0x02F8,             // Range Maximum
                0x01,               // Alignment
                0x08,               // Length
                )
        })
    }

    Device (_SB.COM3)
    {
        Name (_HID, EisaId ("PNP0501") /* 16550A-compatible COM Serial Port */)  // _HID: Hardware ID
        Name (_UID, 0x02)  // _UID: Unique ID
        Name (_DDN, "COM3")  // _DDN: DOS Device Name
        Name (_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
        {
            Interrupt (ResourceConsumer, Edge, ActiveHigh, Exclusive, ,, )
            {
                0x00000004,
            }
            IO (Decode16,
                0x03E8,             // Range Minimum
                0x03E8,             // Range Maximum
                0x01,               // Alignment
                0x08,               // Length
                )
        })
    }

    Device (_SB.COM4)
    {
        Name (_HID, EisaId ("PNP0501") /* 16550A-compatible COM Serial Port */)  // _HID: Hardware ID
        Name (_UID, 0x03)  // _UID: Unique ID
        Name (_DDN, "COM4")  // _DDN: DOS Device Name
        Name (_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
        {
            Interrupt (ResourceConsumer, Edge, ActiveHigh, Exclusive, ,, )
            {
                0x00000003,
            }
            IO (Decode16,
                0x02E8,             // Range Minimum
                0x02E8,             // Range Maximum
                0x01,               // Alignment
                0x08,               // Length
                )
        })
    }

    Device (_SB.PS2)
    {
        Name (_HID, EisaId ("PNP0303") /* IBM Enhanced Keyboard (101/102-key, PS/2 Mouse) */)  // _HID: Hardware ID
        Method (_STA, 0, NotSerialized)  // _STA: Status
        {
            Return (0x0F)
        }

        Name (_CRS, ResourceTemplate ()  // _CRS: Current Resource Settings
        {
            IO (Decode16,
                0x0060,             // Range Minimum
                0x0060,             // Range Maximum
                0x01,               // Alignment
                0x01,               // Length
                )
            IO (Decode16,
                0x0064,             // Range Minimum
                0x0064,             // Range Maximum
                0x01,               // Alignment
                0x01,               // Length
                )
            Interrupt (ResourceConsumer, Edge, ActiveHigh, Exclusive, ,, )
            {
                0x00000001,
            }
        })
    }
}

