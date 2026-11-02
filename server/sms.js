const Core = require('@alicloud/pop-core');

const client = new Core({
  accessKeyId: process.env.ALIBABA_ACCESS_KEY_ID,
  accessKeySecret: process.env.ALIBABA_ACCESS_KEY_SECRET,
  endpoint: 'https://dysmsapi.aliyuncs.com',
  apiVersion: '2017-05-25',
});

async function sendSms(phone, code) {
  const params = {
    RegionId: 'cn-hangzhou',
    PhoneNumbers: phone,
    SignName: '心晴日记',
    TemplateCode: 'SMS_475510093',
    TemplateParam: JSON.stringify({ code }),
  };

  const requestOption = { method: 'POST' };
  const result = await client.request('SendSms', params, requestOption);
  if (result.Code !== 'OK') {
    console.error('SMS send failed:', result.Message);
    throw new Error(result.Message);
  }
  return result;
}

module.exports = { sendSms };
