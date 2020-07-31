//============================================================================
//
//   SSSS    tt          lll  lll
//  SS  SS   tt           ll   ll
//  SS     tttttt  eeee   ll   ll   aaaa
//   SSSS    tt   ee  ee  ll   ll      aa
//      SS   tt   eeeeee  ll   ll   aaaaa  --  "An Atari 2600 VCS Emulator"
//  SS  SS   tt   ee      ll   ll  aa  aa
//   SSSS     ttt  eeeee llll llll  aaaaa
//
// Copyright (c) 1995-2020 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#include "System.hxx"
#include "TIA.hxx"
#include "Cart3EPlus.hxx"

//  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Cartridge3EPlus::Cartridge3EPlus(const ByteBuffer& image, size_t size,
                                 const string& md5, const Settings& settings,
                                 size_t bsSize)
  : Cartridge3E(image, size, md5, settings,
                bsSize == 0 ? BSPF::nextMultipleOf(size, 1_KB) : bsSize)
{
  myBankShift = BANK_SHIFT;
  myRamSize = RAM_SIZE;
  myRamBankCount = RAM_BANKS;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Cartridge3EPlus::reset()
{
  CartridgeEnhanced::reset();

  bank(mySystem->randGenerator().next() % romBankCount(), 0);
  bank(mySystem->randGenerator().next() % romBankCount(), 1);
  bank(mySystem->randGenerator().next() % romBankCount(), 2);
  bank(startBank(), 3);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Cartridge3EPlus::checkSwitchBank(uInt16 address, uInt8 value)
{
  // Switch banks if necessary
  if(address == 0x003F) {
    // Switch ROM bank into segment 0
    bank(value & 0b111111, value >> 6);
    return true;
  }
  else if(address == 0x003E)
  {
    // Switch RAM bank into segment 0
    bank((value & 0b111111) + romBankCount(), value >> 6);
    return true;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 Cartridge3EPlus::peek(uInt16 address)
{
  uInt16 peekAddress = address;
  address &= ROM_MASK;

  if(address < 0x0040)  // TIA peek
    return mySystem->tia().peek(address);

  return CartridgeEnhanced::peek(peekAddress);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Cartridge3EPlus::poke(uInt16 address, uInt8 value)
{
  if(CartridgeEnhanced::poke(address, value))
    return true;

  if(address < 0x0040)  // TIA poke
    // Handle TIA space that we claimed above
    return mySystem->tia().poke(address, value);

  return false;
}
