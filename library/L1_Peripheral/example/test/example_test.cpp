#include "L0_Platform/lpc40xx/LPC40xx.h"
#include "L1_Peripheral/example/example.hpp"
#include "L4_Testing/testing_frameworks.hpp"

namespace sjsu::example
{
// Helps with test coverage. Every object should be wrapped in the
// EMIT_ALL_METHODS macro.
EMIT_ALL_METHODS(Example);

TEST_CASE("Testing L1 example::Example")
{
  // Create mocked versions of the sjsu::Pin
  mockitopp::mock_object<sjsu::Pin> mock_pin_data;
  mock_pin_data(&::SetPinFunction)).when(any<>()).thenReturn();

  mockitopp::mock_object<sjsu::Pin> mock_pin_clock;
  mock_pin_clock(&::SetPinFunction)).when(any<>()).thenReturn();

  // Create a version of the local_iocon
  sjsu::lpc40xx::LPC_IOCON_TypeDef local_iocon;

  // Create a custom Channel_t with the data we plan to inspect.
  Example::Channel_t dependency_injection = {
    .iocon              = &local_iocon,
    .data               = mock_pin_data.get(),
    .clock              = mock_pin_clock.get(),
    .data_pin_function  = 0b100,
    .clock_pin_function = 0b111,
  };

  // Create the object with the custom Channel_t structure with our mocked data.
  Example test_subject(dependency_injection);

  SECTION("Initialize()")
  {
    // Test that the initialize() method actually called the SetPinFunction with
    // the appropriate values
    test_subject.Initialize();
    Verify(Method(mock_pin_data, SetPinFunction)
               .Using(dependency_injection.data_pin_function));
    Verify(Method(mock_pin_clock, SetPinFunction)
               .Using(dependency_injection.clock_pin_function));

    CHECK((local_iocon.P5_3 & 0b1000'0000));
  }
  SECTION("GetValue()")
  {
    CHECK(1'000'000 == test_subject.GetClockRate());
  }
}
}  // namespace sjsu::example
