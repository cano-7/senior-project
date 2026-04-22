#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>

int in1 = 26;
int in2 = 27;
int in3 = 25; //33
int in4 = 33;
int in5 = 32; //14
int in6 = 14;

int freq = 30000;
int resolution = 8;

constexpr uint8_t WIFI_CHANNEL = 1;
constexpr unsigned long COMMAND_TIMEOUT_MS = 250;

enum RobotCommand : uint8_t {
  CMD_STOP = 0,
  CMD_FORWARD = 1,
  CMD_BACKWARD = 2,
  CMD_LEFT = 3,
  CMD_RIGHT = 4
};

struct __attribute__((packed)) ControlPacket {
  uint8_t command;
  uint8_t speed;
  uint16_t sequence;
};

volatile RobotCommand currentCommand = CMD_STOP;
volatile unsigned long lastPacketMs = 0;

void motor(int pinA, int pinB, int speed) {
  speed = constrain(speed, -255, 255);

  if (speed > 0) {
    ledcWrite(pinA, speed);
    ledcWrite(pinB, 0);
  } else {
    ledcWrite(pinA, 0);
    ledcWrite(pinB, -speed);
  }
}

void setMotors(int m1, int m2, int m3) {
  motor(in1, in2, m1);
  motor(in3, in4, m2);
  motor(in5, in6, m3);
}
void applyCommand(RobotCommand cmd) {

  int spd = 255; 

  switch (cmd) {

    case CMD_FORWARD:
      setMotors(spd, -spd, 0);
      break;

    case CMD_BACKWARD:
      setMotors(-spd, spd, 0);
      break;

    case CMD_LEFT:
      setMotors(-spd, -spd, spd);
      break;

    case CMD_RIGHT:
      setMotors(spd, spd, -spd);
      break;

    default:
      setMotors(0, 0, 0);
      break;
  }
}

void onDataRecv(const esp_now_recv_info_t *info, const uint8_t *incomingData, int len) {
  if (len != sizeof(ControlPacket)) return;

  ControlPacket packet;
  memcpy(&packet, incomingData, sizeof(packet));

  currentCommand = (RobotCommand)packet.command;
  lastPacketMs = millis();
}

void setup() {
  Serial.begin(115200);

  ledcAttach(in1, freq, resolution);
  ledcAttach(in2, freq, resolution);
  ledcAttach(in3, freq, resolution);
  ledcAttach(in4, freq, resolution);
  ledcAttach(in5, freq, resolution);
  ledcAttach(in6, freq, resolution);

  setMotors(0, 0, 0);

  WiFi.mode(WIFI_STA);
  esp_wifi_set_channel(WIFI_CHANNEL, WIFI_SECOND_CHAN_NONE);

  if (esp_now_init() != ESP_OK) {
    Serial.println("ESP-NOW INIT FAILED");
    return;
  }

  esp_now_register_recv_cb(onDataRecv);

  Serial.println("FAST + STRAIGHT MODE");
}

void loop() {

  if (millis() - lastPacketMs > COMMAND_TIMEOUT_MS) {
    currentCommand = CMD_STOP;
  }

  applyCommand(currentCommand);

  delay(1);
}


