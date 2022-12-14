import std/strutils
import testground_sdk, chronos, stew/byteutils

type
  AwesomeStruct = object
    message: string

testground(client):
  let
    myId = await client.signalAndWait("setup", client.testInstanceCount)
    myIp = client.testSubnet.split('.')[0..1].join(".") & ".1." & $myId
    serverIp = client.testSubnet.split('.')[0..1].join(".") & ".1.1"
  await client.updateNetworkParameter(
    NetworkConf(
      network: "default",
      ipv4: some myIp & "/24",
      enable: true,
      callback_state: "network_setup",
      callback_target: some client.testInstanceCount,
      routing_policy: "accept_all",
    )
  )

  await client.waitForBarrier("network_setup", client.testInstanceCount)

  # TODO modify this to select the files to upload
  await client.publish("message", AwesomeStruct(message: "SENT"))
  let randomValues = client.subscribe("message", AwesomeStruct)
  for _ in 0 ..< 2:
    echo await randomValues.popFirst()

  let
    payload = client.param(string, "payload")
    count = client.param(int, "count")
    printResult = client.param(bool, "printResult")
  if myId == 1: # server
    let
      server = createStreamServer(initTAddress(myIp & ":5050"), flags = {ReuseAddr})
      connection = await server.accept()

    #TODO here we upload the files to server
    for _ in 0 ..< count:
      doAssert (await connection.write(payload.toBytes())) == payload.len
    connection.close()

  else: # client
    let connection = await connect(initTAddress(serverIp & ":5050"))
    var buffer = newSeq[byte](payload.len)

    #TODO here we download files from server
    for _ in 0 ..< count:
      await connection.readExactly(addr buffer[0], payload.len)
      doAssert string.fromBytes(buffer) == payload
    connection.close()

  if printResult:
    client.recordMessage("Hourray " & $myId & "!")
