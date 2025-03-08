let body = $response.body;

body = body.replace(/<div id="top-ad-banner".*?<\/div>/g, '');

body = body.replace(/<div id="middle-ad-banner".*?<\/div>/g, '');

body = body.replace(/<div id="bottom-ad-banner".*?<\/div>/g, '');

$done({ body });
