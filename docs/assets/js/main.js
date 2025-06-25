fetch('data/members.json')
  .then(r=>r.json())
  .then(m=>{
    let out='';
    m.forEach(u=>{
      const name = u.first ? ` (${u.first} ${u.last})` : '';
      out += `<li><strong>${u.handle}</strong> — Joined ${u.year}${name}</li>`;
    });
    document.getElementById('member-list').innerHTML = out;
  });
