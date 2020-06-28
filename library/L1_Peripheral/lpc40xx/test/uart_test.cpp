#include "L0_Platform/lpc40xx/LPC40xx.h"
#include "L1_Peripheral/lpc40xx/uart.hpp"
#include "L4_Testing/testing_frameworks.hpp"

namespace sjsu::lpc40xx
{
EMIT_ALL_METHODS(Uart);

TEST_CASE("Testing lpc40xx Uart")
{
  // Simulated local version of LPC_UART2 to verify registers
  LPC_UART_TypeDef local_uart;
  testing::ClearStructure(&local_uart);

  // Set mock for sjsu::SystemController
  constexpr units::frequency::hertz_t kDummySystemControllerClockFrequency =
      48_MHz;
  mockitopp::mock_object<sjsu::SystemController> mock_system_controller;
  mock_system_controller(&::PowerUpPeripheral)).when(any<>()).thenReturn();
  When(Method(mock_system_controller, GetClockRate))
      .AlwaysReturn(kDummySystemControllerClockFrequency);

  sjsu::SystemController::SetPlatformController(&mock_system_controller.get());

  mockitopp::mock_object<sjsu::Pin> mock_tx;
  mock_tx(&::SetPinFunction)).when(any<>()).thenReturn();
  mock_tx(&::SetPull)).when(any<>()).thenReturn();
  mockitopp::mock_object<sjsu::Pin> mock_rx;
  mock_rx(&::SetPinFunction)).when(any<>()).thenReturn();
  mock_rx(&::SetPull)).when(any<>()).thenReturn();

  // Set up for UART2
  // Parameters for constructor
  const Uart::Port_t kMockUart2 = {
    .registers      = &local_uart,
    .power_on_id    = sjsu::lpc40xx::SystemController::Peripherals::kUart2,
    .tx             = mock_tx.get(),
    .rx             = mock_rx.get(),
    .tx_function_id = 0b001,
    .rx_function_id = 0b001,
  };
  constexpr uint32_t kBaudRate = 9600;

  Uart uart_test(kMockUart2);
  uart_test.Initialize(kBaudRate);

  SECTION("Initialize")
  {
    constexpr uint32_t kFifo              = 1 << 0;
    constexpr uint32_t kBits8DlabClear    = 3;
    constexpr uint32_t kExpectedUpperByte = 0;
    constexpr uint32_t kExpectedLowerByte = 208;
    constexpr uint32_t kExpectedDivAdd    = 1;
    constexpr uint32_t kExpectedMul       = 2;
    constexpr uint32_t kExpectedFdr = (kExpectedMul << 4) | kExpectedDivAdd;

    Verify(Method(mock_system_controller, PowerUpPeripheral)
               .Matching([](sjsu::SystemController::ResourceID id) {
                 return sjsu::lpc40xx::SystemController::Peripherals::kUart2
                            .device_id == id.device_id;
               }));

    Verify(Method(mock_tx, SetPull).Using(sjsu::Pin::Resistor::kPullUp)).Once();
    Verify(Method(mock_tx, SetPinFunction).Using(kMockUart2.tx_function_id))
        .Once();
    Verify(Method(mock_rx, SetPull).Using(sjsu::Pin::Resistor::kPullUp)).Once();
    Verify(Method(mock_tx, SetPinFunction).Using(kMockUart2.rx_function_id))
        .Once();

    CHECK(kExpectedUpperByte == local_uart.DLM);
    CHECK(kExpectedLowerByte == local_uart.DLL);
    CHECK(kExpectedFdr == local_uart.FDR);
    CHECK(kBits8DlabClear == local_uart.LCR);
    CHECK(kFifo == (local_uart.FCR & kFifo));
  }

  sjsu::lpc40xx::SystemController::system_controller = LPC_SC;
}
}  // namespace sjsu::lpc40xx
