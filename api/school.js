export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  const { region, name } = req.query;
  if (!name) return res.status(400).json({ error: 'name required' });

  const NEIS_KEY = process.env.NEIS_API_KEY;
  const regionCodes = {
    '서울':'B10','부산':'C10','대구':'D10','인천':'E10',
    '광주':'F10','대전':'G10','울산':'H10','세종':'I10',
    '경기':'J10','강원':'K10','충북':'M10','충남':'N10',
    '전북':'P10','전남':'Q10','경북':'R10','경남':'S10','제주':'T10'
  };

  const code = regionCodes[region] || '';
  const url = `https://open.neis.go.kr/hub/schoolInfo?KEY=${NEIS_KEY}&Type=json&pSize=20${code ? '&ATPT_OFCDC_SC_CODE=' + code : ''}&SCHUL_NM=${encodeURIComponent(name)}`;

  try {
    const response = await fetch(url);
    const data = await response.json();
    const schools = data?.schoolInfo?.[1]?.row || [];
    return res.status(200).json({ schools });
  } catch(e) {
    return res.status(500).json({ error: e.message });
  }
}
