#include "L1_Peripheral/stm32f10x/uart.hpp"
#include "utility/time.hpp"
#include "utility/log.hpp"

int main()
{
  sjsu::LogInfo("Starting Uart Application...");

  sjsu::stm32f10x::Uart<128> uart1(sjsu::stm32f10x::UartBase::Port::kUart1);
  uart1.Initialize();
  uart1.ConfigureFormat();
  uart1.ConfigureBaudRate(38400);
  uart1.Enable();

  sjsu::LogInfo(
      "Connect the TX (PA9) RX (PA10) and pins to a USB to serial converter "
      "with baud rate 38400. Anything sent to the board via serial will be "
      "repeated back.");

  while (true)
  {
    while (uart1.HasData())
    {
      uart1.Write(uart1.Read());
    }
  }

  return 0;
}
