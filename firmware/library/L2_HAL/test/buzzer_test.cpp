#include "L2_HAL/buzzer.hpp"
#include "L1_Drivers/pwm.hpp"
#include "L4_Testing/testing_frameworks.hpp"

EMIT_ALL_METHODS(Buzzer);

TEST_CASE("Testing buzzer", "[buzzer]")
{
  // Create mock for PWM class
  Mock<PwmInterface> mock_pwm_pin;

  Fake(Method(mock_pwm_pin, Initialize), Method(mock_pwm_pin, SetDutyCycle),
       Method(mock_pwm_pin, SetFrequency));

  PwmInterface & pwm = mock_pwm_pin.get();

  // Instantiate buzzer test objects
  Buzzer test1(&pwm);

  SECTION("Check Initialize")
  {
    constexpr uint32_t kFrequency = 500;
    constexpr float kVolume       = 0.0f;
    test1.Initialize();
    Verify(Method(mock_pwm_pin, Initialize).Using(500),
           Method(mock_pwm_pin, SetDutyCycle).Using(kVolume/2)),
        Method(mock_pwm_pin, SetFrequency).Using(kFrequency);
  }

  SECTION("Check Beep")
  {
    constexpr uint32_t kFrequency = 500;
    constexpr float kVolume       = 0.5f;
    test1.Beep(kFrequency, kVolume);

    // NOTE: Since the PWM is at its loudest at 50% duty cycle, the maximum PWM
    // is divided by 2.
    Verify(Method(mock_pwm_pin, SetDutyCycle).Using(kVolume/2));
    Verify(Method(mock_pwm_pin, SetFrequency).Using(kFrequency));
  }

  SECTION("Check Stop")
  {
    test1.Stop();
    Verify(Method(mock_pwm_pin, SetDutyCycle).Using(0)),
        Method(mock_pwm_pin, SetFrequency).Using(0);
  }
}
